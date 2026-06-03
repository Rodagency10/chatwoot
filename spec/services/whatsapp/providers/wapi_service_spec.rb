# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::Providers::WapiService do
  subject(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  let!(:account) { create(:account) }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp,
           account: account,
           provider: 'wapi',
           provider_config: {
             'wapi_url' => 'https://wapi.example.com',
             'wapi_basic_auth' => 'dXNlcjpwYXNz',
             'device_id' => 'test-device-uuid'
           },
           sync_templates: false,
           validate_provider_config: false)
  end

  describe '#send_message' do
    it 'returns a fake success response' do
      result = service.send_message('+123456789', 'Hello')
      expect(result[:success]).to be true
      expect(result[:messages].first[:id]).to match(/^wapi-webhook-/)
    end
  end

  describe '#send_template' do
    it 'falls back to send_message' do
      message = create(:message, message_type: :outgoing, content: 'Test template', inbox: whatsapp_channel.inbox)
      result = service.send_template('+123456789', {}, message)
      expect(result[:success]).to be true
    end
  end

  describe '#sync_templates' do
    it 'clears message_templates and updates timestamp' do
      whatsapp_channel.update!(message_templates: [{ name: 'old_template' }])
      service.sync_templates
      whatsapp_channel.reload
      expect(whatsapp_channel.message_templates).to eq([])
      expect(whatsapp_channel.message_templates_last_updated).not_to be_nil
    end
  end

  describe '#validate_provider_config?' do
    context 'when wapi_url and basic_auth are present' do
      it 'returns true' do
        expect(service.validate_provider_config?).to be true
      end
    end

    context 'when wapi_url is missing' do
      before { whatsapp_channel.provider_config['wapi_url'] = nil }

      it 'returns false' do
        expect(service.validate_provider_config?).to be false
      end
    end

    context 'when basic_auth is missing' do
      before { whatsapp_channel.provider_config['wapi_basic_auth'] = nil }

      it 'returns false' do
        expect(service.validate_provider_config?).to be false
      end
    end
  end

  describe '#api_headers' do
    it 'returns authorization and content-type headers' do
      headers = service.api_headers
      expect(headers['Authorization']).to eq('Basic dXNlcjpwYXNz')
      expect(headers['Content-Type']).to eq('application/json')
    end
  end

  describe '#media_url' do
    it 'returns the file URL from WAPI' do
      expect(service.media_url('media-123')).to eq('https://wapi.example.com/files/media-123')
    end
  end

  describe '#error_message' do
    it 'extracts message from response' do
      expect(service.error_message({ 'message' => 'Something failed' })).to eq('Something failed')
    end

    it 'falls back to error key' do
      expect(service.error_message({ 'error' => 'Error occurred' })).to eq('Error occurred')
    end

    it 'returns default when no message or error' do
      expect(service.error_message({})).to eq('Unknown WAPI error')
    end

    it 'returns default when response is nil' do
      expect(service.error_message(nil)).to eq('Unknown WAPI error')
    end
  end
end
