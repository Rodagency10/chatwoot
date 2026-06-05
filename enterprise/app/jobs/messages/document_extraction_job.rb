class Messages::DocumentExtractionJob < ApplicationJob
  queue_as :low

  retry_on ActiveStorage::FileNotFoundError, wait: 2.seconds, attempts: 3

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    return if attachment.blank?
    return unless attachment.file_type.to_sym == :file
    return unless Messages::DocumentExtractionService.extractable?(attachment)

    raise ActiveStorage::FileNotFoundError unless attachment.file.attached?

    Messages::DocumentExtractionService.new(attachment).perform
  end
end
