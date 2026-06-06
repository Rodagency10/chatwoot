class Captain::Tools::SendAttachmentTool < Captain::Tools::BasePublicTool
  description 'Send an image attachment to the customer in the conversation'
  param :image_url, type: 'string', desc: 'HTTPS URL of the image to send'
  param :caption, type: 'string', desc: 'Optional caption text shown with the image', required: false

  def perform(tool_context, image_url:, caption: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation
    return 'Image URL is required' if image_url.blank?

    log_tool_usage('send_attachment', { conversation_id: conversation.id, image_url: image_url })

    service = Captain::Messages::OutgoingAttachmentService.new(assistant: @assistant, conversation: conversation)
    service.send_from_url(image_url: image_url, caption: caption)
    'Image sent successfully'
  rescue Captain::Messages::OutgoingAttachmentService::Error, Captain::UrlSafetyValidator::Error, SafeFetch::Error => e
    "Failed to send image: #{e.message}"
  end
end
