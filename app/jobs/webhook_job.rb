class WebhookJob < ApplicationJob
  queue_as :medium
  #  There are 3 types of webhooks, account, inbox and agent_bot
  def perform(url, payload, webhook_type = :account_webhook, **options)
    message_id = options[:message_id]
    event = options[:event]
    payload = Message.find(message_id).webhook_data.merge(event: event) if message_id.present?

    Webhooks::Trigger.execute(
      url, payload, webhook_type,
      secret: options[:secret], delivery_id: options[:delivery_id]
    )
  end
end
