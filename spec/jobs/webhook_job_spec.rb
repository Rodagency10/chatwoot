require 'rails_helper'

RSpec.describe WebhookJob do
  include ActiveJob::TestHelper

  subject(:job) { described_class.perform_later(url, payload, webhook_type) }

  let(:url) { 'https://test.chatwoot.com' }
  let(:payload) { { name: 'test' } }
  let(:webhook_type) { :account_webhook }

  it 'queues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(url, payload, webhook_type)
      .on_queue('medium')
  end

  it 'executes perform with default webhook type' do
    expect(Webhooks::Trigger).to receive(:execute).with(url, payload, webhook_type, secret: nil, delivery_id: nil)
    perform_enqueued_jobs { job }
  end

  context 'with custom webhook type' do
    let(:webhook_type) { :api_inbox_webhook }

    it 'executes perform with inbox webhook type' do
      expect(Webhooks::Trigger).to receive(:execute).with(url, payload, webhook_type, secret: nil, delivery_id: nil)
      perform_enqueued_jobs { job }
    end
  end

  context 'when message_id is provided' do
    let!(:account) { create(:account) }
    let!(:inbox) { create(:inbox, account: account) }
    let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let!(:message) { create(:message, :with_attachment, account: account, inbox: inbox, conversation: conversation) }

    it 'rebuilds payload from the message' do
      expected_payload = message.webhook_data.merge(event: 'message_created')

      expect(Webhooks::Trigger).to receive(:execute).with(
        url, expected_payload, webhook_type, secret: nil, delivery_id: nil
      )

      described_class.perform_now(url, nil, webhook_type, message_id: message.id, event: 'message_created')
    end
  end
end
