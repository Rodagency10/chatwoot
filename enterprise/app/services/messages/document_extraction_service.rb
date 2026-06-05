require 'csv'
require 'pdf/reader'
require 'zip'

class Messages::DocumentExtractionService
  EXTRACTION_BYTE_LIMIT = 10_000_000
  MAX_EXTRACTED_TEXT_LENGTH = 50_000

  EXTRACTABLE_EXTENSIONS = %w[pdf docx doc txt csv rtf json xml].freeze

  EXTRACTABLE_CONTENT_TYPES = %w[
    application/pdf
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/msword
    text/plain
    text/csv
    text/rtf
    text/xml
    application/rtf
    application/json
    application/xml
  ].freeze

  attr_reader :attachment, :message, :account

  def self.extractable?(attachment)
    return false unless attachment.file_type.to_sym == :file

    new(attachment).send(:document_format).present?
  end

  def initialize(attachment)
    @attachment = attachment
    @message = attachment.message
    @account = message&.account
  end

  def perform
    validation_error = extraction_validation_error
    return validation_error if validation_error

    cached_response = cached_extraction_response
    return cached_response if cached_response

    extract_and_store
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, Zip::Error => e
    Rails.logger.warn("Document extraction failed for attachment #{attachment.id}: #{e.message}")
    { error: 'Extraction failed' }
  end

  private

  def extraction_validation_error
    return { error: 'Extraction not available' } unless can_extract?
    return { error: 'Message not found' } if message.blank?
    return { error: 'Document too large' } if document_too_large?
    return { error: 'File not attached' } unless attachment.file.attached?

    nil
  end

  def cached_extraction_response
    cached_text = attachment.meta&.[]('extracted_text')
    return if cached_text.blank?

    { success: true, extracted_text: cached_text }
  end

  def extract_and_store
    extracted_text = extract_document_text
    return { error: 'Extraction failed' } if extracted_text.blank?

    update_extraction(extracted_text)
    { success: true, extracted_text: extracted_text }
  end

  def can_extract?
    account.feature_enabled?('captain_integration') && document_format.present?
  end

  def document_too_large?
    blob = attachment.file&.blob
    return false unless blob

    blob.byte_size > EXTRACTION_BYTE_LIMIT
  end

  def document_format
    if attachment.file.attached?
      content_type = attachment.file.blob.content_type.to_s.downcase.split(';').first.to_s
      format = content_type_to_format(content_type)
      return format if format.present?
    end

    extension_to_format(attachment.extension.presence || file_extension)
  end

  def content_type_to_format(content_type)
    case content_type
    when 'application/pdf' then :pdf
    when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' then :docx
    when 'application/msword' then :doc
    when 'text/plain', 'text/csv', 'application/json', 'application/xml', 'text/xml' then :text
    when 'text/rtf', 'application/rtf' then :rtf
    end
  end

  def extension_to_format(extension)
    case extension.to_s.downcase
    when 'pdf' then :pdf
    when 'docx' then :docx
    when 'doc' then :doc
    when 'txt', 'csv', 'json', 'xml' then :text
    when 'rtf' then :rtf
    end
  end

  def file_extension
    File.extname(attachment.file.filename.to_s).delete_prefix('.').downcase
  end

  def extract_document_text
    with_tempfile do |temp_file_path|
      raw_text = extract_text_from_path(temp_file_path, document_format)
      truncate_text(raw_text)
    end
  end

  def extract_text_from_path(path, format)
    case format
    when :pdf then extract_pdf_text(path)
    when :docx then extract_docx_text(path)
    when :doc then extract_doc_text(path)
    when :text then extract_plain_text(path)
    when :rtf then extract_rtf_text(path)
    else
      ''
    end
  end

  def extract_pdf_text(path)
    PDF::Reader.new(path).pages.map(&:text).join("\n").squish
  end

  def extract_docx_text(path)
    text = +''
    Zip::File.open(path) do |zip_file|
      entry = zip_file.find_entry('word/document.xml')
      return '' if entry.blank?

      xml = Nokogiri::XML(entry.get_input_stream.read)
      text = xml.xpath('//*[local-name()="t"]').map(&:text).join(' ')
    end
    text.squish
  end

  def extract_doc_text(path)
    data = File.binread(path)

    utf16_text = data.scan(/(?:[\x20-\x7E]\x00){4,}/).map do |chunk|
      chunk.dup.force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace, replace: ' ')
    end.join(' ').squish
    return utf16_text if utf16_text.length > 20

    data.force_encoding('ASCII-8BIT').scan(/[\x20-\x7E]{4,}/).join(' ').squish
  end

  def extract_plain_text(path)
    content = File.read(path, mode: 'rb')
    content = content.encode('UTF-8', invalid: :replace, undef: :replace, replace: ' ')
    return content.squish unless file_extension == 'csv'

    CSV.parse(content, liberal_parsing: true).flatten.compact.join(' ').squish
  rescue CSV::MalformedCSVError
    content.squish
  end

  def extract_rtf_text(path)
    content = File.read(path, mode: 'rb').encode('UTF-8', invalid: :replace, undef: :replace, replace: ' ')
    content.gsub(/\\[a-z]+\d*\s?/, ' ')
           .gsub(/[{}]/, ' ')
           .gsub(/\s+/, ' ')
           .strip
  end

  def truncate_text(text)
    normalized = text.to_s.squish
    return '' if normalized.blank?
    return normalized if normalized.length <= MAX_EXTRACTED_TEXT_LENGTH

    normalized[0, MAX_EXTRACTED_TEXT_LENGTH]
  end

  def with_tempfile
    blob = attachment.file.blob
    temp_dir = Rails.root.join('tmp/uploads/document-extractions')
    FileUtils.mkdir_p(temp_dir)
    temp_file_path = File.join(temp_dir, "#{blob.key}-#{blob.filename}")

    File.open(temp_file_path, 'wb') do |file|
      blob.open do |blob_file|
        IO.copy_stream(blob_file, file)
      end
    end

    yield temp_file_path
  ensure
    FileUtils.rm_f(temp_file_path) if temp_file_path.present?
  end

  def update_extraction(extracted_text)
    attachment.update!(meta: (attachment.meta || {}).merge('extracted_text' => extracted_text))
    message.reload.send_update_event

    return unless ChatwootApp.advanced_search_allowed?

    message.reindex
  end
end
