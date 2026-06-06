require 'rails_helper'

RSpec.describe Captain::Messages::OutgoingAttachmentService, type: :service do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(assistant: assistant, conversation: conversation) }

  describe '#send_from_url' do
    let(:image_url) { 'https://example.com/product.svg' }
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join('public/assets/images/dashboard/captain/logo.svg').open,
        filename: 'product.svg',
        content_type: 'image/svg+xml'
      )
    end

    before do
      allow(Captain::UrlSafetyValidator).to receive(:validate_url!).with(image_url).and_return(URI.parse(image_url))
      allow(SafeFetch).to receive(:fetch).and_yield(
        SafeFetch::Result.new(
          tempfile: blob.open,
          filename: 'product.svg',
          content_type: 'image/svg+xml'
        )
      )
      allow(ActiveStorage::Blob).to receive(:create_and_upload!).and_return(blob)
    end

    it 'creates an outgoing message with an image attachment' do
      expect do
        message = service.send_from_url(image_url: image_url, caption: 'Gold ring')
        expect(message.content).to eq('Gold ring')
        expect(message.sender).to eq(assistant)
        expect(message.attachments.first.file_type).to eq('image')
      end.to change(Message, :count).by(1)
    end
  end

  describe '#send_from_blob' do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join('public/assets/images/dashboard/captain/logo.svg').open,
        filename: 'product.svg',
        content_type: 'image/svg+xml'
      )
    end

    it 'creates an outgoing message from an existing blob' do
      message = service.send_from_blob(blob: blob, caption: 'Catalog item')
      expect(message.attachments.first.file.attached?).to be(true)
    end
  end
end
