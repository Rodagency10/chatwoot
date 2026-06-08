class Captain::Messages::OutgoingAttachmentService
  class Error < StandardError; end

  MAX_ATTACHMENT_BYTES = 10_000_000
  IMAGE_CONTENT_TYPE_PREFIX = 'image/'.freeze

  pattr_initialize [:assistant!, :conversation!]

  def send_from_url(image_url:, caption: nil)
    blob = download_image_blob(image_url)
    create_message_with_attachment(blob: blob, caption: caption)
  end

  def send_from_blob(blob:, caption: nil)
    validate_image_blob!(blob)
    create_message_with_attachment(blob: blob, caption: caption)
  end

  private

  def download_image_blob(image_url)
    Captain::UrlSafetyValidator.validate_url!(image_url)

    SafeFetch.fetch(
      image_url,
      max_bytes: MAX_ATTACHMENT_BYTES,
      allowed_content_type_prefixes: [IMAGE_CONTENT_TYPE_PREFIX]
    ) do |result|
      ActiveStorage::Blob.create_and_upload!(
        io: result.tempfile,
        filename: result.filename,
        content_type: result.content_type
      )
    end
  end

  def validate_image_blob!(blob)
    content_type = blob.content_type.to_s
    return if content_type.start_with?(IMAGE_CONTENT_TYPE_PREFIX)

    raise Error, 'Attachment must be an image'
  end

  def create_message_with_attachment(blob:, caption:)
    message = conversation.messages.build(
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: assistant,
      content: caption
    )

    message.attachments.build(
      account_id: conversation.account_id,
      file_type: :image,
      file: blob
    )

    message.save!
    message
  end
end
