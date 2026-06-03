# frozen_string_literal: true

# Service for managing WAPI (whatsameow) devices.
# Handles device creation, QR retrieval, status polling, config save, and cleanup.
class Wapi::DeviceService
  attr_reader :wapi_url, :basic_auth

  def initialize(wapi_url:, basic_auth:)
    @wapi_url = wapi_url.chomp('/')
    @basic_auth = basic_auth
  end

  # POST /devices
  def create_device(device_id)
    request(:post, '/devices', { device_id: device_id })
  end

  # GET /app/login
  def get_qr(device_id)
    request(:get, '/app/login', nil, device_id: device_id)
  end

  # GET /app/login-with-code?phone=...
  def login_with_code(device_id, phone)
    request(:get, '/app/login-with-code', nil, device_id: device_id, query: { phone: phone })
  end

  # GET /app/status
  def check_status(device_id)
    request(:get, '/app/status', nil, device_id: device_id)
  end

  # GET /app/reconnect
  def reconnect(device_id)
    request(:get, '/app/reconnect', nil, device_id: device_id)
  end

  # GET /app/logout
  def logout(device_id)
    request(:get, '/app/logout', nil, device_id: device_id)
  end

  # GET /devices/:device_id
  def get_device(device_id)
    request(:get, "/devices/#{CGI.escape(device_id)}")
  end

  # GET /devices
  def list_devices
    request(:get, '/devices')
  end

  # PUT /devices/:device_id/chatwoot
  def save_chatwoot_config(device_id, chatwoot_url:, api_token:, account_id:, inbox_id:)
    request(
      :put,
      "/devices/#{CGI.escape(device_id)}/chatwoot",
      {
        chatwoot_url: chatwoot_url,
        api_token: api_token,
        account_id: account_id,
        inbox_id: inbox_id,
        enabled: true
      },
      device_id: device_id
    )
  end

  # Full cleanup: remove config → logout → delete device
  def cleanup(device_id)
    # 1. Remove Chatwoot config
    request(:delete, "/devices/#{CGI.escape(device_id)}/chatwoot", nil, device_id: device_id)
  rescue StandardError => e
    Rails.logger.warn "[WAPI] Failed to remove config for #{device_id}: #{e.message}"
  ensure
    # 2. Logout
    begin
      request(:post, "/devices/#{CGI.escape(device_id)}/logout", nil, device_id: device_id)
    rescue StandardError => e
      Rails.logger.warn "[WAPI] Failed to logout device #{device_id}: #{e.message}"
    end

    # 3. Delete device
    begin
      request(:delete, "/devices/#{CGI.escape(device_id)}")
    rescue StandardError => e
      Rails.logger.warn "[WAPI] Failed to delete device #{device_id}: #{e.message}"
    end
  end

  private

  def request(method, path, body = nil, device_id: nil, query: nil)
    uri = build_uri(path, query)
    http = build_http(uri)
    req = build_request(method, uri, body, device_id)
    parse_response(http.request(req))
  end

  def build_uri(path, query)
    uri = URI("#{wapi_url}#{path}")
    uri.query = URI.encode_www_form(query) if query.present?
    uri
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 15
    http
  end

  def build_request(method, uri, body, device_id)
    headers = base_headers(device_id)
    req_class = http_method_class(method)
    req = req_class.new(uri.request_uri, headers)
    req.body = body.to_json if body.present?
    req
  end

  def base_headers(device_id)
    headers = {
      'Authorization' => "Basic #{basic_auth}",
      'Content-Type' => 'application/json'
    }
    headers['X-Device-Id'] = device_id if device_id.present?
    headers
  end

  def http_method_class(method)
    case method
    when :get    then Net::HTTP::Get
    when :post   then Net::HTTP::Post
    when :put    then Net::HTTP::Put
    when :delete then Net::HTTP::Delete
    else raise ArgumentError, "Unsupported HTTP method: #{method}"
    end
  end

  def parse_response(response)
    body = response.body
    return {} if body.blank?

    data = JSON.parse(body)
    return data if data['code'] == 'SUCCESS'

    raise CustomExceptions::WapiError, data['message'] || "WAPI request failed (HTTP #{response.code})"
  rescue JSON::ParserError
    raise CustomExceptions::WapiError, "Invalid JSON response from WAPI (HTTP #{response.code})"
  end
end
