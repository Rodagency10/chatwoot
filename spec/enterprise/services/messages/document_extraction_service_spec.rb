require 'rails_helper'

RSpec.describe Messages::DocumentExtractionService, type: :service do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, conversation: conversation) }
  let(:attachment) { message.attachments.create!(account: account, file_type: :file) }
  let(:service) { described_class.new(attachment) }

  before do
    account.enable_features!('captain_integration')
  end

  describe '.extractable?' do
    it 'returns true for supported file types' do
      attachment.file.attach(
        io: StringIO.new('name,email'),
        filename: 'contacts.csv',
        content_type: 'text/csv'
      )

      expect(described_class.extractable?(attachment)).to be(true)
    end

    it 'returns false for unsupported file types' do
      attachment.file.attach(
        io: StringIO.new('binary'),
        filename: 'archive.zip',
        content_type: 'application/zip'
      )

      expect(described_class.extractable?(attachment)).to be(false)
    end
  end

  describe '#perform' do
    context 'when captain_integration feature is not enabled' do
      before do
        account.disable_features!('captain_integration')
      end

      it 'returns extraction not available' do
        expect(service.perform).to eq({ error: 'Extraction not available' })
      end
    end

    context 'when attachment already has extracted text' do
      before do
        attachment.update!(meta: { extracted_text: 'Existing document text' })
      end

      it 'returns cached text without re-extracting' do
        expect(service).not_to receive(:extract_document_text)
        expect(service.perform).to eq({ success: true, extracted_text: 'Existing document text' })
      end
    end

    context 'when extracting plain text' do
      before do
        attachment.file.attach(
          io: StringIO.new("Hello document\nSecond line"),
          filename: 'notes.txt',
          content_type: 'text/plain'
        )
      end

      it 'returns extracted text' do
        result = service.perform
        expect(result[:success]).to be(true)
        expect(result[:extracted_text]).to eq('Hello document Second line')
        expect(attachment.reload.meta['extracted_text']).to eq('Hello document Second line')
      end
    end

    context 'when extracting csv' do
      before do
        attachment.file.attach(
          io: File.open(Rails.root.join('spec/assets/contacts.csv')),
          filename: 'contacts.csv',
          content_type: 'text/csv'
        )
      end

      it 'returns flattened csv content' do
        result = service.perform
        expect(result[:success]).to be(true)
        expect(result[:extracted_text]).to include('name')
        expect(result[:extracted_text]).to include('email')
      end
    end

    context 'when extracting docx' do
      before do
        attachment.file.attach(
          io: StringIO.new(build_docx_bytes('Bonjour depuis DOCX')),
          filename: 'sample.docx',
          content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )
      end

      it 'returns extracted text' do
        result = service.perform
        expect(result[:success]).to be(true)
        expect(result[:extracted_text]).to include('Bonjour depuis DOCX')
      end
    end

    context 'when document is too large' do
      before do
        attachment.file.attach(
          io: StringIO.new('small'),
          filename: 'large.txt',
          content_type: 'text/plain'
        )
        allow(attachment.file.blob).to receive(:byte_size).and_return(described_class::EXTRACTION_BYTE_LIMIT + 1)
      end

      it 'returns an error' do
        expect(service.perform).to eq({ error: 'Document too large' })
      end
    end
  end

  def build_docx_bytes(text)
    document_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
          <w:p><w:r><w:t>#{text}</w:t></w:r></w:p>
        </w:body>
      </w:document>
    XML

    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry('word/document.xml')
      zip.write(document_xml)
    end

    buffer.string
  end
end
