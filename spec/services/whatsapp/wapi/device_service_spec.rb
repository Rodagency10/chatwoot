# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::Wapi::DeviceService do
  subject(:service) { described_class.new(wapi_url: wapi_url, basic_auth: basic_auth) }

  let(:wapi_url) { 'https://wapi.example.com' }
  let(:basic_auth) { 'dXNlcjpwYXNz' }
  let(:device_id) { 'test-device-uuid' }
  let(:default_headers) { { 'Authorization' => 'Basic dXNlcjpwYXNz', 'Content-Type' => 'application/json' } }

  describe '#create_device' do
    it 'sends POST to /devices' do
      stub_request(:post, "#{wapi_url}/devices")
        .with(body: { device_id: device_id }.to_json, headers: default_headers)
        .to_return(status: 200, body: { code: 'SUCCESS', data: { id: device_id } }.to_json)

      result = service.create_device(device_id)
      expect(result['code']).to eq('SUCCESS')
    end

    it 'raises WapiError on failure' do
      stub_request(:post, "#{wapi_url}/devices")
        .to_return(status: 400, body: { code: 'ERROR', message: 'Device already exists' }.to_json)

      expect { service.create_device(device_id) }.to raise_error(Whatsapp::Wapi::DeviceService::WapiError, 'Device already exists')
    end
  end

  describe '#get_qr' do
    it 'sends GET to /app/login with X-Device-Id header' do
      stub_request(:get, "#{wapi_url}/app/login")
        .with(headers: default_headers.merge('X-Device-Id' => device_id))
        .to_return(status: 200, body: { code: 'SUCCESS', data: 'qr-base64-string' }.to_json)

      result = service.get_qr(device_id)
      expect(result['data']).to eq('qr-base64-string')
    end
  end

  describe '#login_with_code' do
    it 'sends GET to /app/login-with-code with phone query param' do
      stub_request(:get, "#{wapi_url}/app/login-with-code?phone=1234567890")
        .with(headers: default_headers.merge('X-Device-Id' => device_id))
        .to_return(status: 200, body: { code: 'SUCCESS', data: { code: 'ABCD-1234' } }.to_json)

      result = service.login_with_code(device_id, '1234567890')
      expect(result['data']['code']).to eq('ABCD-1234')
    end
  end

  describe '#check_status' do
    it 'sends GET to /app/status with X-Device-Id header' do
      stub_request(:get, "#{wapi_url}/app/status")
        .with(headers: default_headers.merge('X-Device-Id' => device_id))
        .to_return(status: 200, body: { code: 'SUCCESS', data: 'connected' }.to_json)

      result = service.check_status(device_id)
      expect(result['data']).to eq('connected')
    end

    it 'returns disconnected status' do
      stub_request(:get, "#{wapi_url}/app/status")
        .to_return(status: 200, body: { code: 'SUCCESS', data: 'disconnected' }.to_json)

      result = service.check_status(device_id)
      expect(result['data']).to eq('disconnected')
    end
  end

  describe '#get_device' do
    it 'sends GET to /devices/:device_id' do
      stub_request(:get, "#{wapi_url}/devices/#{CGI.escape(device_id)}")
        .with(headers: default_headers)
        .to_return(status: 200, body: { code: 'SUCCESS', data: { id: device_id } }.to_json)

      result = service.get_device(device_id)
      expect(result['data']['id']).to eq(device_id)
    end
  end

  describe '#list_devices' do
    it 'sends GET to /devices' do
      stub_request(:get, "#{wapi_url}/devices")
        .with(headers: default_headers)
        .to_return(status: 200, body: { code: 'SUCCESS', data: [{ id: device_id }] }.to_json)

      result = service.list_devices
      expect(result['data'].length).to eq(1)
    end
  end

  describe '#save_chatwoot_config' do
    it 'sends PUT to /devices/:device_id/chatwoot' do
      expected_body = {
        chatwoot_url: 'https://chatwoot.example.com',
        api_token: 'test-token',
        account_id: 1,
        inbox_id: 2,
        enabled: true
      }.to_json

      stub_request(:put, "#{wapi_url}/devices/#{CGI.escape(device_id)}/chatwoot")
        .with(body: expected_body, headers: default_headers.merge('X-Device-Id' => device_id))
        .to_return(status: 200, body: { code: 'SUCCESS' }.to_json)

      result = service.save_chatwoot_config(
        device_id,
        chatwoot_url: 'https://chatwoot.example.com',
        api_token: 'test-token',
        account_id: 1,
        inbox_id: 2
      )
      expect(result['code']).to eq('SUCCESS')
    end
  end

  describe '#cleanup' do
    it 'removes config, logs out, and deletes device' do
      # Config removal may fail, but logout and delete should still run
      stub_request(:delete, "#{wapi_url}/devices/#{CGI.escape(device_id)}/chatwoot")
        .to_return(status: 404, body: { code: 'ERROR', message: 'Not found' }.to_json)

      stub_request(:post, "#{wapi_url}/devices/#{CGI.escape(device_id)}/logout")
        .to_return(status: 200, body: { code: 'SUCCESS' }.to_json)

      stub_request(:delete, "#{wapi_url}/devices/#{CGI.escape(device_id)}")
        .to_return(status: 200, body: { code: 'SUCCESS' }.to_json)

      expect(Rails.logger).to receive(:warn).with(/Failed to remove config/)

      service.cleanup(device_id)
    end

    it 'continues cleanup even if logout fails' do
      stub_request(:delete, "#{wapi_url}/devices/#{CGI.escape(device_id)}/chatwoot")
        .to_return(status: 200, body: { code: 'SUCCESS' }.to_json)

      stub_request(:post, "#{wapi_url}/devices/#{CGI.escape(device_id)}/logout")
        .to_return(status: 500, body: { code: 'ERROR' }.to_json)

      stub_request(:delete, "#{wapi_url}/devices/#{CGI.escape(device_id)}")
        .to_return(status: 200, body: { code: 'SUCCESS' }.to_json)

      expect(Rails.logger).to receive(:warn).with(/Failed to logout/)

      service.cleanup(device_id)
    end
  end

  describe 'WapiError' do
    it 'is a StandardError subclass' do
      expect(Whatsapp::Wapi::DeviceService::WapiError.ancestors).to include(StandardError)
    end
  end
end
