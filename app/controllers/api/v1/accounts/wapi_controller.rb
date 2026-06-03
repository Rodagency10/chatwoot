# frozen_string_literal: true

class Api::V1::Accounts::WapiController < Api::V1::Accounts::BaseController
  before_action :validate_wapi_env
  before_action :fetch_inbox, except: [:create_inbox]

  # POST /api/v1/accounts/:account_id/wapi/create_inbox
  def create_inbox
    inbox_name = params[:name]
    render json: { error: 'Inbox name is required' }, status: :unprocessable_entity and return if inbox_name.blank?

    ActiveRecord::Base.transaction do
      channel = Current.account.channel_api.create!(webhook_url: '')
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
    result = device_service.get_qr(device_id)
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

    result = device_service.login_with_code(device_id, phone)
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
    jid = fetch_device_jid
    save_wapi_config
    finalize_connection(jid)

    phone_number = extract_phone_from_jid(jid) if jid.present?
    render json: { success: true, phone_number: phone_number, jid: jid }
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

  def fetch_device_jid
    devices_result = device_service.list_devices
    devices = devices_result['results'] || []
    device = devices.find { |d| d['id'] == device_id }
    device&.dig('jid')
  end

  def save_wapi_config
    device_service.save_chatwoot_config(
      device_id,
      chatwoot_url: ENV.fetch('FRONTEND_URL', request.base_url),
      api_token: current_user.access_token,
      account_id: Current.account.id,
      inbox_id: @inbox.id
    )
  end

  def finalize_connection(jid)
    create_wapi_webhook("#{wapi_base_url}/chatwoot/webhook")
    @channel.update!(additional_attributes: @channel.additional_attributes.merge('wapi_jid' => jid))
  end

  def extract_phone_from_jid(jid)
    # JID format: 22870111810@s.whatsapp.net → +22870111810
    phone = jid.split('@').first
    "+#{phone}" if phone.present?
  end

  def create_wapi_webhook(webhook_url)
    # Create an account webhook with only message_created subscription
    # This matches the manual WAPI setup: Settings > Integrations > Webhooks
    # Note: must be account_type because deliver_account_webhooks only dispatches account_type
    existing = Current.account.webhooks.find_by(url: webhook_url)
    return existing if existing.present?

    Current.account.webhooks.create!(
      url: webhook_url,
      subscriptions: ['message_created']
    )
  end
end
