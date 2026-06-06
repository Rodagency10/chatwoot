require 'rails_helper'

RSpec.describe Captain::Tools::SendAttachmentTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:tool) { described_class.new(assistant) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:tool_context) { Struct.new(:state).new({ conversation: { id: conversation.id } }) }

  describe '#perform' do
    it 'sends an image from a valid URL' do
      service = instance_double(Captain::Messages::OutgoingAttachmentService, send_from_url: build(:message, conversation: conversation))
      allow(Captain::Messages::OutgoingAttachmentService).to receive(:new).and_return(service)

      result = tool.perform(tool_context, image_url: 'https://example.com/product.png', caption: 'Ring')
      expect(result).to eq('Image sent successfully')
      expect(service).to have_received(:send_from_url).with(image_url: 'https://example.com/product.png', caption: 'Ring')
    end

    it 'returns an error when the URL is blocked' do
      service = instance_double(Captain::Messages::OutgoingAttachmentService)
      allow(Captain::Messages::OutgoingAttachmentService).to receive(:new).and_return(service)
      allow(service).to receive(:send_from_url).and_raise(
        Captain::UrlSafetyValidator::Error, 'Request blocked'
      )

      result = tool.perform(tool_context, image_url: 'https://localhost/image.png')
      expect(result).to include('Failed to send image')
    end
  end
end
