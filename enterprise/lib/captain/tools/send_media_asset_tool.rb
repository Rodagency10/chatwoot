class Captain::Tools::SendMediaAssetTool < Captain::Tools::BasePublicTool
  description 'Send product image(s) from the media catalog to the customer'
  param :asset_id, type: 'integer', desc: 'ID of the media catalog asset to send'
  param :caption, type: 'string', desc: 'Optional caption text shown with the image', required: false
  param :image_index, type: 'integer', desc: '1-based image position; omit to send the primary image', required: false
  param :image_label, type: 'string', desc: 'Image label such as back or detail; omit to send the primary image', required: false
  param :send_all, type: 'boolean', desc: 'Send all product images; use only when the customer explicitly asks for every view', required: false

  def perform(tool_context, asset_id:, caption: nil, image_index: nil, image_label: nil, send_all: false)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    asset = account_scoped(Captain::MediaAsset)
            .for_assistant(@assistant.id)
            .active
            .includes(images: { file_attachment: :blob })
            .find_by(id: asset_id)
    return 'Media asset not found' if asset.blank?
    return 'Media asset has no images attached' if asset.images.none?

    service = Captain::Messages::OutgoingAttachmentService.new(assistant: @assistant, conversation: conversation)

    if ActiveModel::Type::Boolean.new.cast(send_all)
      return send_all_images(service, asset, caption, conversation)
    end

    image = asset.image_for_send(image_index: image_index, image_label: image_label) || asset.primary_image
    return 'Requested image was not found for this product' if image.blank? || !image.file.attached?

    final_caption = caption.presence || asset.build_caption(@assistant, image: image)

    log_tool_usage('send_media_asset', {
                     conversation_id: conversation.id,
                     asset_id: asset.id,
                     image_id: image.id,
                     send_all: false
                   })

    service.send_from_blob(blob: image.file.blob, caption: final_caption)
    "Image sent successfully: #{asset.name}"
  rescue Captain::Messages::OutgoingAttachmentService::Error => e
    "Failed to send image: #{e.message}"
  end

  private

  def send_all_images(service, asset, caption, conversation)
    images = asset.images.ordered.select { |image| image.file.attached? }
    return 'Media asset has no images attached' if images.blank?

    log_tool_usage('send_media_asset', {
                     conversation_id: conversation.id,
                     asset_id: asset.id,
                     send_all: true,
                     image_count: images.size
                   })

    images.each_with_index do |image, index|
      final_caption = if index.zero?
                        caption.presence || asset.build_caption(@assistant, image: image)
                      else
                        asset.build_caption(@assistant, image: image)
                      end
      service.send_from_blob(blob: image.file.blob, caption: final_caption)
    end

    "Sent #{images.size} images for: #{asset.name}"
  rescue Captain::Messages::OutgoingAttachmentService::Error => e
    "Failed to send images: #{e.message}"
  end
end
