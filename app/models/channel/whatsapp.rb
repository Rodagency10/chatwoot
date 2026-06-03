# == Schema Information
#
# Table name: channel_whatsapp
#
#  id                             :bigint           not null, primary key
#  message_templates              :jsonb
#  message_templates_last_updated :datetime
#  phone_number                   :string
#  provider                       :string           default("default")
#  provider_config                :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  account_id                     :integer          not null
#
# Indexes
#
#  index_channel_whatsapp_on_phone_number  (phone_number) UNIQUE
#

class Channel::Whatsapp < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_whatsapp'
  EDITABLE_ATTRS = [:phone_number, :provider, { provider_config: {} }].freeze

  # default at the moment is 360dialog lets change later.
  PROVIDERS = %w[default whatsapp_cloud wapi].freeze
  before_validation :ensure_webhook_verify_token, unless: :wapi_provider?

  validates :provider, inclusion: { in: PROVIDERS }
  validates :phone_number, presence: true, uniqueness: true, unless: :wapi_provider?
  validate :validate_provider_config, unless: :wapi_provider?

  after_create :sync_templates
  before_destroy :teardown_webhooks
  before_destroy :cleanup_wapi_device, if: :wapi_provider?
  after_commit :setup_webhooks, on: :create, if: :should_auto_setup_webhooks?

  def name
    'Whatsapp'
  end

  # Mirrors Channel::TwilioSms#voice_enabled? so the call subsystem can duck-type across providers.
  # Meta's Calling API is available to any whatsapp_cloud inbox (embedded-signup or manual keys);
  # only 360dialog (default provider) can't reach the call APIs.
  def voice_enabled?
    voice_calling_supported? &&
      provider_config['calling_enabled'].present? &&
      account.feature_enabled?('channel_voice')
  end

  # Whether this inbox can do WhatsApp calling at all. Meta's Calling API is
  # reachable by any whatsapp_cloud inbox, so 360dialog inboxes can't be toggled
  # on even though calling_enabled would persist.
  def voice_calling_supported?
    provider == 'whatsapp_cloud'
  end

  def provider_service
    case provider
    when 'whatsapp_cloud'
      Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
    when 'wapi'
      Whatsapp::Providers::WapiService.new(whatsapp_channel: self)
    else
      Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
    end
  end

  # Enables voice: turns calling on at Meta (idempotent), subscribes the `calls`
  # webhook field, and sets calling_enabled. Raises on Meta failure.
  # Saved with validate: false to skip validate_provider_config's remote credential
  # re-check, which could spuriously fail and desync the flag from Meta.
  def enable_voice_calling!
    raise 'WhatsApp calling requires a whatsapp_cloud inbox' unless voice_calling_supported?
    raise 'WhatsApp calling requires the channel_voice feature' unless account.feature_enabled?('channel_voice')

    provider_service.update_calling_status('ENABLED')
    webhook_setup_service.register_callback
    self.provider_config = provider_config.merge('calling_enabled' => true)
    save!(validate: false)
  end

  # Disables voice: unsets calling_enabled (gates the call subsystem) and drops
  # `calls` from the webhook subscription (best-effort, so a Meta outage can't
  # trap admins). Leaves Meta's WABA calling.status untouched.
  def disable_voice_calling!
    raise 'WhatsApp calling requires a whatsapp_cloud inbox' unless voice_calling_supported?

    self.provider_config = provider_config.merge('calling_enabled' => false)
    save!(validate: false)
    begin
      webhook_setup_service.register_callback(subscribed_fields: %w[messages smb_message_echoes])
    rescue StandardError => e
      Rails.logger.warn "[WHATSAPP CALL] disable webhook re-subscribe failed: #{e.message}"
    end
  end

  def mark_message_templates_updated
    # rubocop:disable Rails/SkipsModelValidations
    update_column(:message_templates_last_updated, Time.zone.now)
    # rubocop:enable Rails/SkipsModelValidations
  end

  delegate :send_message, to: :provider_service
  delegate :send_template, to: :provider_service
  delegate :sync_templates, to: :provider_service
  delegate :media_url, to: :provider_service
  delegate :api_headers, to: :provider_service

  def wapi_provider?
    provider == 'wapi'
  end

  def setup_webhooks
    perform_webhook_setup
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Webhook setup failed: #{e.message}"
    prompt_reauthorization!
  end

  private

  def ensure_webhook_verify_token
    provider_config['webhook_verify_token'] ||= SecureRandom.hex(16) if provider == 'whatsapp_cloud'
  end

  def validate_provider_config
    errors.add(:provider_config, 'Invalid Credentials') unless provider_service.validate_provider_config?
  end

  def perform_webhook_setup
    webhook_setup_service.perform
  end

  def webhook_setup_service
    Whatsapp::WebhookSetupService.new(self, provider_config['business_account_id'], provider_config['api_key'])
  end

  def teardown_webhooks
    Whatsapp::WebhookTeardownService.new(self).perform
  end

  def should_auto_setup_webhooks?
    # Only auto-setup webhooks for whatsapp_cloud provider with manual setup
    # Embedded signup calls setup_webhooks explicitly in EmbeddedSignupService
    provider == 'whatsapp_cloud' && provider_config['source'] != 'embedded_signup'
  end

  def cleanup_wapi_device
    device_id = provider_config['device_id']
    return if device_id.blank?

    Whatsapp::Wapi::DeviceService.new(
      wapi_url: wapi_base_url,
      basic_auth: wapi_basic_auth
    ).cleanup(device_id)
  rescue StandardError => e
    Rails.logger.error "[WAPI] Failed to cleanup device #{device_id}: #{e.message}"
  end

  def wapi_base_url
    provider_config['wapi_url'].presence || ENV.fetch('WAPI_BASE_URL', nil)
  end

  def wapi_basic_auth
    provider_config['wapi_basic_auth'].presence || ENV.fetch('WAPI_BASIC_AUTH', nil)
  end
end
