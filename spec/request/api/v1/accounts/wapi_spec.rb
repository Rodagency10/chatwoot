# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WAPI Inbox API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:api_channel) do
    create(:channel_api,
           account: account,
           webhook_url: '',
           additional_attributes: { 'wapi_device_id' => 'test-device-uuid' })
  end
  let(:inbox) { create(:inbox, account: account, channel: api_channel) }

  describe 'POST /api/v1/accounts/{account.id}/wapi/create_inbox' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/wapi/create_inbox"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      around do |example|
        with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
          example.run
        end
      end

      it 'creates an API inbox and WAPI device' do
        device_service = instance_double(Wapi::DeviceService)
        allow(Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:create_device).and_return({ 'code' => 'SUCCESS' })

        post "/api/v1/accounts/#{account.id}/wapi/create_inbox",
             params: { name: 'WhatsApp Support' },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['inbox_id']).to be_present
        expect(json['device_id']).to be_present

        created_inbox = Inbox.find(json['inbox_id'])
        expect(created_inbox.channel_type).to eq('Channel::Api')
        expect(created_inbox.channel.additional_attributes['wapi_device_id']).to be_present
      end

      it 'returns error when name is missing' do
        post "/api/v1/accounts/#{account.id}/wapi/create_inbox",
             params: {},
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Inbox name is required')
      end

      it 'returns error when WAPI call fails' do
        device_service = instance_double(Wapi::DeviceService)
        allow(Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:create_device)
          .and_raise(CustomExceptions::WapiError, 'Device creation failed')

        post "/api/v1/accounts/#{account.id}/wapi/create_inbox",
             params: { name: 'Support' },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Device creation failed')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/wapi/qr' do
    around do |example|
      with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
        example.run
      end
    end

    context 'when authenticated' do
      it 'returns QR code' do
        device_service = instance_double(Wapi::DeviceService)
        allow(Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:get_qr)
          .and_return({ 'code' => 'SUCCESS', 'results' => { 'qr_link' => 'https://wapi.example.com/qr.png', 'qr_duration' => 30 } })

        get "/api/v1/accounts/#{account.id}/wapi/qr",
            params: { inbox_id: inbox.id },
            headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['qr']).to eq('https://wapi.example.com/qr.png')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/wapi/login_with_code' do
    around do |example|
      with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
        example.run
      end
    end

    context 'when phone is missing' do
      it 'returns unprocessable entity' do
        post "/api/v1/accounts/#{account.id}/wapi/login_with_code",
             params: { inbox_id: inbox.id },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Phone number is required')
      end
    end

    context 'when phone is provided' do
      it 'returns pairing code' do
        device_service = instance_double(Wapi::DeviceService)
        allow(Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:login_with_code)
          .and_return({ 'code' => 'SUCCESS', 'results' => { 'pair_code' => 'ABCD-1234' } })

        post "/api/v1/accounts/#{account.id}/wapi/login_with_code",
             params: { inbox_id: inbox.id, phone: '1234567890' },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['pair_code']).to eq('ABCD-1234')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/wapi/status' do
    around do |example|
      with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
        example.run
      end
    end

    context 'when authenticated' do
      it 'returns device status' do
        device_service = instance_double(Wapi::DeviceService)
        allow(Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:check_status)
          .and_return({ 'code' => 'SUCCESS', 'results' => { 'is_connected' => true, 'is_logged_in' => true } })

        get "/api/v1/accounts/#{account.id}/wapi/status",
            params: { inbox_id: inbox.id },
            headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['status']).to eq('connected')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/wapi/connect' do
    around do |example|
      with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
        example.run
      end
    end

    context 'when authenticated' do
      let(:device_service) { instance_double(Wapi::DeviceService) }

      before do
        allow(Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:save_chatwoot_config)
          .and_return({ 'code' => 'SUCCESS', 'results' => { 'device_id' => '22890000000@s.whatsapp.net' } })

        post "/api/v1/accounts/#{account.id}/wapi/connect",
             params: { inbox_id: inbox.id },
             headers: administrator.create_new_auth_token,
             as: :json
      end

      it 'returns success with phone number and jid' do
        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['phone_number']).to eq('+22890000000')
        expect(json['jid']).to eq('22890000000@s.whatsapp.net')
      end

      it 'stores JID and sets channel webhook_url' do
        api_channel.reload
        expect(api_channel.additional_attributes['wapi_jid']).to eq('22890000000@s.whatsapp.net')
        expect(api_channel.webhook_url).to eq('https://wapi.example.com/chatwoot/webhook')
      end
    end
  end

  describe 'environment validation' do
    context 'when WAPI env vars are not set' do
      around do |example|
        with_modified_env WAPI_BASE_URL: nil, WAPI_BASIC_AUTH: nil do
          example.run
        end
      end

      it 'returns service unavailable' do
        post "/api/v1/accounts/#{account.id}/wapi/create_inbox",
             params: { name: 'Test' },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body['error']).to eq('WAPI environment variables not configured')
      end
    end
  end
end
