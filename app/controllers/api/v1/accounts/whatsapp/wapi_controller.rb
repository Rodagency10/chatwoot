# frozen_string_literal: true

class Api::V1::Accounts::Whatsapp::WapiController < Api::V1::Accounts::BaseController
  before_action :fetch_whatsapp_channel
  before_action :validate_wapi_env

  # POST /api/v1/accounts/:account_id/whatsapp/wapi/create_device
  def create_device
    device_id = SecureRandom.uuid
    result = device_service.create_device(device_id)
    @whatsapp_channel.update!(
      provider: 'wapi',
      provider_config: @whatsapp_channel.provider_config.merge(
        'device_id' => device_id,
        'wapi_url' => wapi_base_url,
        'wapi_basic_auth' => wapi_basic_auth
      )
    )
    render json: { success: true, device_id: device_id }
  rescue Whatsapp::Wapi::DeviceService::WapiError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/whatsapp/wapi/qr
  def qr
    result = device_service.get_qr(device_id)
    render json: { success: true, qr: result['data'] }
  rescue Whatsapp::Wapi::DeviceService::WapiError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/whatsapp/wapi/login_with_code
  def login_with_code
    phone = params[:phone]
    render json: { success: false, error: 'Phone number is required' }, status: :unprocessable_entity and return if phone.blank?

    result = device_service.login_with_code(device_id, phone)
    render json: { success: true, data: result['data'] }
  rescue Whatsapp::Wapi::DeviceService::WapiError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/whatsapp/wapi/status
  def status
    result = device_service.check_status(device_id)
    render json: { success: true, status: result['data'] }
  rescue Whatsapp::Wapi::DeviceService::WapiError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/whatsapp/wapi/connect
  def connect
    api_token = params[:api_token]
    render json: { success: false, error: 'API token is required' }, status: :unprocessable_entity and return if api_token.blank?

    chatwoot_url = ENV.fetch('FRONTEND_URL', request.base_url)
    device_service.save_chatwoot_config(
      device_id,
      chatwoot_url: chatwoot_url,
      api_token: api_token,
      account_id: @whatsapp_channel.account_id,
      inbox_id: @whatsapp_channel.inbox.id
    )
    render json: { success: true, message: 'Device connected successfully' }
  rescue Whatsapp::Wapi::DeviceService::WapiError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_whatsapp_channel
    inbox = Current.account.inboxes.find(params[:inbox_id])
    @whatsapp_channel = inbox.channel
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Inbox not found' }, status: :not_found
  end

  def validate_wapi_env
    return if wapi_base_url.present? && wapi_basic_auth.present?

    render json: { success: false, error: 'WAPI environment variables not configured' }, status: :service_unavailable
  end

  def device_service
    @device_service ||= Whatsapp::Wapi::DeviceService.new(
      wapi_url: wapi_base_url,
      basic_auth: wapi_basic_auth
    )
  end

  def device_id
    @whatsapp_channel.provider_config['device_id']
  end

  def wapi_base_url
    ENV.fetch('WAPI_BASE_URL', nil)
  end

  def wapi_basic_auth
    ENV.fetch('WAPI_BASIC_AUTH', nil)
  end
end
