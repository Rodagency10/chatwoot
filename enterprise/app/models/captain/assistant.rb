# == Schema Information
#
# Table name: captain_assistants
#
#  id                  :bigint           not null, primary key
#  config              :jsonb            not null
#  description         :string
#  guardrails          :jsonb
#  name                :string           not null
#  response_guidelines :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#
# Indexes
#
#  index_captain_assistants_on_account_id  (account_id)
#
class Captain::Assistant < ApplicationRecord
  include Avatarable
  include Concerns::CaptainToolsHelpers
  include Concerns::Agentable

  self.table_name = 'captain_assistants'

  belongs_to :account
  has_many :documents, class_name: 'Captain::Document', dependent: :destroy_async
  has_many :media_assets, class_name: 'Captain::MediaAsset', dependent: :destroy_async
  has_many :responses, class_name: 'Captain::AssistantResponse', dependent: :destroy_async
  has_many :captain_inboxes,
           class_name: 'CaptainInbox',
           foreign_key: :captain_assistant_id,
           dependent: :destroy_async
  has_many :inboxes,
           through: :captain_inboxes
  has_many :messages, as: :sender, dependent: :nullify
  has_many :copilot_threads, dependent: :destroy_async
  has_many :scenarios, class_name: 'Captain::Scenario', dependent: :destroy_async

  store_accessor :config, :temperature, :feature_faq, :feature_memory, :feature_contact_attributes, :product_name,
                 :send_handoff_message, :send_resolution_message, :response_delay_seconds

  validates :name, presence: true
  validates :description, presence: true
  validates :account_id, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  scope :for_account, ->(account_id) { where(account_id: account_id) }

  def available_name
    name
  end

  def send_handoff_message?
    config_flag_enabled?('send_handoff_message')
  end

  def send_resolution_message?
    config_flag_enabled?('send_resolution_message')
  end

  def response_delay_seconds
    value = config['response_delay_seconds'].to_i
    value.clamp(0, 300)
  end

  def keyword_activation_enabled?
    config_flag_enabled?('keyword_activation_enabled')
  end

  def activation_label
    config['activation_label'].presence || Captain::Conversation::KeywordActivationGate::DEFAULT_ACTIVATION_LABEL
  end

  def activation_keywords
    Array(config['activation_keywords']).map(&:to_s).map(&:strip).compact_blank
  end

  def activation_match_mode
    config['activation_match_mode'].presence || 'word'
  end

  def activation_word_match_mode?
    activation_match_mode != 'substring'
  end

  def available_agent_tools
    tools = self.class.built_in_agent_tools.dup

    custom_tools = account.captain_custom_tools.enabled.map(&:to_tool_metadata)
    tools.concat(custom_tools)

    tools
  end

  def available_tool_ids
    available_agent_tools.pluck(:id)
  end

  def push_event_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  def webhook_data
    {
      id: id,
      name: name,
      avatar_url: avatar_url.presence || default_avatar_url,
      description: description,
      created_at: created_at,
      type: 'captain_assistant'
    }
  end

  private

  def config_flag_enabled?(key)
    return false unless config.key?(key)

    ActiveModel::Type::Boolean.new.cast(config[key])
  end

  def agent_name
    name.parameterize(separator: '_')
  end

  def agent_tools
    [
      self.class.resolve_tool_class('faq_lookup').new(self),
      self.class.resolve_tool_class('handoff').new(self)
    ]
  end

  def prompt_context
    {
      name: name,
      description: description,
      product_name: config['product_name'] || 'this product',
      scenarios: scenarios.enabled.map do |scenario|
        {
          title: scenario.title,
          key: scenario.handoff_key,
          description: scenario.description
        }
      end,
      response_guidelines: response_guidelines || [],
      guardrails: guardrails || []
    }
  end

  def default_avatar_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/assets/images/dashboard/captain/logo.svg"
  end
end
