require 'rails_helper'

RSpec.describe Captain::Tools::SendMediaAssetTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:tool) { described_class.new(assistant) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }
  let!(:media_asset) { create(:captain_media_asset, assistant: assistant, account: account, name: 'Gold ring') }

  describe '#perform' do
    it 'sends the primary catalog image to the conversation' do
      service = instance_double(
        Captain::Messages::OutgoingAttachmentService,
        send_from_blob: build(:message, conversation: conversation)
      )
      allow(Captain::Messages::OutgoingAttachmentService).to receive(:new).and_return(service)

      result = tool.perform(tool_context, asset_id: media_asset.id)
      expect(result).to eq('Image sent successfully: Gold ring')
      expect(service).to have_received(:send_from_blob)
    end

    it 'returns not found for unknown assets' do
      result = tool.perform(tool_context, asset_id: 99_999)
      expect(result).to eq('Media asset not found')
    end

    it 'sends all images when send_all is true' do
      create(:captain_media_asset_image, media_asset: media_asset, position: 1, label: 'back')

      service = instance_double(
        Captain::Messages::OutgoingAttachmentService,
        send_from_blob: build(:message, conversation: conversation)
      )
      allow(Captain::Messages::OutgoingAttachmentService).to receive(:new).and_return(service)

      result = tool.perform(tool_context, asset_id: media_asset.id, send_all: true)
      expect(result).to eq('Sent 2 images for: Gold ring')
      expect(service).to have_received(:send_from_blob).twice
    end
  end
end
