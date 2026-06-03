# frozen_string_literal: true

# Stub provider for WAPI (whatsameow self-hosted).
# Outgoing messages are handled by the native Chatwoot webhook → WAPI,
# so this service only needs to return success to prevent retry loops.
class Whatsapp::Providers::WapiService < Whatsapp::Providers::BaseService
  def send_message(_phone_number, _message)
    # Outgoing messages are routed via the Chatwoot webhook → WAPI.
    # Return a fake success so Chatwoot marks the message as sent.
    { success: true, messages: [{ id: "wapi-webhook-#{SecureRandom.hex(8)}" }] }
  end

  def send_template(_phone_number, _template_info, _message)
    # WAPI doesn't support Meta templates. Fallback to session message.
    send_message(nil, nil)
  end

  def sync_templates
    # WAPI doesn't use Meta message templates.
    @whatsapp_channel.update!(message_templates: [], message_templates_last_updated: Time.current)
  end

  def validate_provider_config?
    wapi_url.present? && basic_auth.present?
  end

  def api_headers
    {
      'Authorization' => "Basic #{basic_auth}",
      'Content-Type' => 'application/json'
    }
  end

  def media_url(media_id)
    "#{wapi_url}/files/#{media_id}"
  end

  def error_message(response)
    response&.dig('message') || response&.dig('error') || 'Unknown WAPI error'
  end

  private

  def wapi_url
    @whatsapp_channel.provider_config['wapi_url'].presence || ENV.fetch('WAPI_BASE_URL', nil)
  end

  def basic_auth
    @whatsapp_channel.provider_config['wapi_basic_auth'].presence || ENV.fetch('WAPI_BASIC_AUTH', nil)
  end
end
