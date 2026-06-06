# frozen_string_literal: true

class Api::V1::Accounts::WapiController < Api::V1::Accounts::BaseController
  before_action :validate_wapi_env
  before_action :fetch_inbox, except: [:create_inbox]

  # POST /api/v1/accounts/:account_id/wapi/create_inbox
  def create_inbox
    inbox_name = params[:name]
    render json: { error: 'Inbox name is required' }, status: :unprocessable_entity and return if inbox_name.blank?

    ActiveRecord::Base.transaction do
      channel = Current.account.api_channels.create!(webhook_url: '')
      @inbox = Current.account.inboxes.create!(name: inbox_name.strip, channel: channel)
      device_id = "cw-inbox-#{@inbox.id}"

      device_service.create_device(device_id)

      channel.update!(additional_attributes: channel.additional_attributes.merge('wapi_device_id' => device_id))
    end

    render json: { success: true, inbox_id: @inbox.id, device_id: @inbox.channel.additional_attributes['wapi_device_id'] }
  rescue CustomExceptions::WapiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/wapi/qr
  def qr
    result = with_device_recovery { device_service.get_qr(device_id) }
    render json: {
      success: true,
      qr: result.dig('results', 'qr_link'),
      qr_duration: result.dig('results', 'qr_duration') || 30
    }
  rescue CustomExceptions::WapiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/wapi/login_with_code
  def login_with_code
    phone = params[:phone]
    render json: { error: 'Phone number is required' }, status: :unprocessable_entity and return if phone.blank?

    result = with_device_recovery { device_service.login_with_code(device_id, phone) }
    render json: { success: true, pair_code: result.dig('results', 'pair_code') }
  rescue CustomExceptions::WapiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/wapi/status
  def status
    result = device_service.check_status(device_id)
    wapi_status = result['results'] || {}
    connected = wapi_status['is_connected'] && wapi_status['is_logged_in']
    render json: { success: true, status: connected ? 'connected' : 'disconnected' }
  rescue CustomExceptions::WapiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/wapi/connect
  def connect
    config_result = save_wapi_config
    jid = config_result.dig('results', 'device_id')
    finalize_connection(jid)

    phone_number = extract_phone_from_jid(jid) if jid.present?
    render json: { success: true, phone_number: phone_number, jid: jid }
  rescue CustomExceptions::WapiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/wapi/device_info
  def device_info
    connected = device_connected?

    render json: {
      success: true,
      device_id: device_id,
      jid: @channel.additional_attributes['wapi_jid'],
      phone_number: extract_phone_from_jid(@channel.additional_attributes['wapi_jid']),
      is_connected: connected,
      needs_login: !connected
    }
  end

  # POST /api/v1/accounts/:account_id/wapi/reconnect
  def reconnect
    device_service.reconnect(device_id)
    render json: { success: true }
  rescue CustomExceptions::WapiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/wapi/logout
  def logout
    device_service.logout(device_id)
    @channel.update!(additional_attributes: @channel.additional_attributes.except('wapi_jid'))
    render json: { success: true }
  rescue CustomExceptions::WapiError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    @channel = @inbox.channel
    return if @channel.is_a?(Channel::Api)

    render json: { error: 'Inbox is not a WAPI channel' }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Inbox not found' }, status: :not_found
  end

  def validate_wapi_env
    return if wapi_base_url.present? && wapi_basic_auth.present?

    render json: { error: 'WAPI environment variables not configured' }, status: :service_unavailable
  end

  def device_service
    @device_service ||= Wapi::DeviceService.new(wapi_url: wapi_base_url, basic_auth: wapi_basic_auth)
  end

  def device_id
    @channel.additional_attributes['wapi_device_id']
  end

  def wapi_base_url
    ENV.fetch('WAPI_BASE_URL', nil)
  end

  def wapi_basic_auth
    ENV.fetch('WAPI_BASIC_AUTH', nil)
  end

  def save_wapi_config
    device_service.save_chatwoot_config(
      device_id,
      chatwoot_url: ENV.fetch('FRONTEND_URL', request.base_url),
      api_token: current_user.access_token.token,
      account_id: Current.account.id,
      inbox_id: @inbox.id
    )
  end

  def finalize_connection(jid)
    @channel.update!(
      webhook_url: "#{wapi_base_url}/chatwoot/webhook",
      additional_attributes: @channel.additional_attributes.merge('wapi_jid' => jid)
    )
  end

  def extract_phone_from_jid(jid)
    return if jid.blank?

    # JID format: 22890000000@s.whatsapp.net → +22890000000
    phone = jid.split('@').first
    "+#{phone}" if phone.present?
  end

  def device_connected?
    status_result = device_service.check_status(device_id)
    wapi_status = status_result['results'] || {}
    wapi_status['is_connected'] && wapi_status['is_logged_in']
  rescue CustomExceptions::WapiError
    false
  end

  def with_device_recovery
    yield
  rescue CustomExceptions::WapiError => e
    raise unless Wapi::DeviceService.recoverable_session_error?(e.message)

    recreate_device!
    yield
  end

  def recreate_device!
    device_service.create_device(device_id)
  rescue CustomExceptions::WapiError => e
    raise unless Wapi::DeviceService.device_already_exists_error?(e.message)
  end
end
