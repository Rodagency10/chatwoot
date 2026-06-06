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
    it 'sends a catalog image to the conversation' do
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
  end
end
