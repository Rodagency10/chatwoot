# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WhatsApp WAPI API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp,
           account: account,
           provider: 'wapi',
           provider_config: {
             'device_id' => 'test-device-uuid',
             'wapi_url' => 'https://wapi.example.com',
             'wapi_basic_auth' => 'dXNlcjpwYXNz'
           },
           sync_templates: false,
           validate_provider_config: false)
  end
  let(:inbox) { create(:inbox, account: account, channel: whatsapp_channel) }

  describe 'POST /api/v1/accounts/{account.id}/whatsapp/wapi/create_device' do
    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/create_device"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      around do |example|
        with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
          example.run
        end
      end

      it 'creates a device and updates channel config' do
        device_service = instance_double(Whatsapp::Wapi::DeviceService)
        allow(Whatsapp::Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:create_device).and_return({ 'code' => 'SUCCESS' })

        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/create_device",
             params: { inbox_id: inbox.id },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['device_id']).to be_present
      end

      it 'returns error when WAPI call fails' do
        device_service = instance_double(Whatsapp::Wapi::DeviceService)
        allow(Whatsapp::Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:create_device)
          .and_raise(CustomExceptions::WapiError, 'Device creation failed')

        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/create_device",
             params: { inbox_id: inbox.id },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Device creation failed')
      end

      it 'returns not found when inbox does not exist' do
        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/create_device",
             params: { inbox_id: 99_999 },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/whatsapp/wapi/qr' do
    around do |example|
      with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
        example.run
      end
    end

    context 'when authenticated' do
      it 'returns QR code' do
        device_service = instance_double(Whatsapp::Wapi::DeviceService)
        allow(Whatsapp::Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:get_qr)
          .and_return({ 'code' => 'SUCCESS', 'results' => { 'qr_link' => 'https://wapi.example.com/qr.png', 'qr_duration' => 30 } })

        get "/api/v1/accounts/#{account.id}/whatsapp/wapi/qr",
            params: { inbox_id: inbox.id },
            headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['qr']).to eq('https://wapi.example.com/qr.png')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/whatsapp/wapi/login_with_code' do
    around do |example|
      with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
        example.run
      end
    end

    context 'when phone is missing' do
      it 'returns unprocessable entity' do
        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/login_with_code",
             params: { inbox_id: inbox.id },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Phone number is required')
      end
    end

    context 'when phone is provided' do
      it 'returns pairing code' do
        device_service = instance_double(Whatsapp::Wapi::DeviceService)
        allow(Whatsapp::Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:login_with_code)
          .and_return({ 'code' => 'SUCCESS', 'results' => { 'pair_code' => 'ABCD-1234' } })

        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/login_with_code",
             params: { inbox_id: inbox.id, phone: '1234567890' },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['data']['code']).to eq('ABCD-1234')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/whatsapp/wapi/status' do
    around do |example|
      with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
        example.run
      end
    end

    context 'when authenticated' do
      it 'returns device status' do
        device_service = instance_double(Whatsapp::Wapi::DeviceService)
        allow(Whatsapp::Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:check_status)
          .and_return({ 'code' => 'SUCCESS', 'results' => { 'is_connected' => true, 'is_logged_in' => true } })

        get "/api/v1/accounts/#{account.id}/whatsapp/wapi/status",
            params: { inbox_id: inbox.id },
            headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['status']).to eq('connected')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/whatsapp/wapi/connect' do
    around do |example|
      with_modified_env WAPI_BASE_URL: 'https://wapi.example.com', WAPI_BASIC_AUTH: 'dXNlcjpwYXNz' do
        example.run
      end
    end

    context 'when api_token is missing' do
      it 'returns unprocessable entity' do
        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/connect",
             params: { inbox_id: inbox.id },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('API token is required')
      end
    end

    context 'when api_token is provided' do
      it 'saves chatwoot config and returns success' do
        device_service = instance_double(Whatsapp::Wapi::DeviceService)
        allow(Whatsapp::Wapi::DeviceService).to receive(:new).and_return(device_service)
        allow(device_service).to receive(:save_chatwoot_config).and_return({ 'code' => 'SUCCESS' })

        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/connect",
             params: { inbox_id: inbox.id, api_token: 'user-api-token' },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['message']).to eq('Device connected successfully')
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
        post "/api/v1/accounts/#{account.id}/whatsapp/wapi/create_device",
             params: { inbox_id: inbox.id },
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body['error']).to eq('WAPI environment variables not configured')
      end
    end
  end
end
