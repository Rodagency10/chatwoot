class Captain::Tools::SendMediaAssetTool < Captain::Tools::BasePublicTool
  description 'Send a product image from the media catalog to the customer'
  param :asset_id, type: 'integer', desc: 'ID of the media catalog asset to send'
  param :caption, type: 'string', desc: 'Optional caption text shown with the image', required: false

  def perform(tool_context, asset_id:, caption: nil)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    asset = account_scoped(Captain::MediaAsset)
            .for_assistant(@assistant.id)
            .active
            .find_by(id: asset_id)
    return 'Media asset not found' if asset.blank?
    return 'Media asset has no image attached' unless asset.image.attached?

    final_caption = caption.presence || asset.build_caption(@assistant)

    log_tool_usage('send_media_asset', { conversation_id: conversation.id, asset_id: asset.id })

    service = Captain::Messages::OutgoingAttachmentService.new(assistant: @assistant, conversation: conversation)
    service.send_from_blob(blob: asset.image.blob, caption: final_caption)
    "Image sent successfully: #{asset.name}"
  rescue Captain::Messages::OutgoingAttachmentService::Error => e
    "Failed to send image: #{e.message}"
  end
end
