require 'rails_helper'

RSpec.describe Captain::Conversation::ResponseScheduler do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
  let(:assistant) { create(:captain_assistant, account: account) }

  before do
    clear_schedule_keys
  end

  after do
    clear_schedule_keys
  end

  describe '#schedule' do
    it 'enqueues an immediate response job when delay and attachment wait are zero' do
      expect do
        described_class.new(conversation: conversation, assistant: assistant).schedule
      end.to have_enqueued_job(Captain::Conversation::ResponseBuilderJob).with(
        conversation,
        assistant,
        schedule_token: kind_of(String),
        triggered_at: kind_of(Time)
      )
    end

    it 'enqueues a delayed job when response_delay_seconds is configured' do
      assistant.update!(config: { 'response_delay_seconds' => 30, 'response_batching_enabled' => true })

      freeze_time do
        expect do
          described_class.new(conversation: conversation, assistant: assistant).schedule
        end.to have_enqueued_job(Captain::Conversation::ResponseBuilderJob)
          .with(conversation, assistant, schedule_token: kind_of(String), triggered_at: kind_of(Time))

        scheduled_at = enqueued_response_job_at
        expect(Time.zone.at(scheduled_at)).to be_within(2.seconds).of(30.seconds.from_now)
      end
    end

    it 'uses attachment wait when it is longer than the configured delay' do
      assistant.update!(config: { 'response_delay_seconds' => 1 })

      freeze_time do
        expect do
          described_class.new(conversation: conversation, assistant: assistant, attachment_wait: 4).schedule
        end.to have_enqueued_job(Captain::Conversation::ResponseBuilderJob)

        scheduled_at = enqueued_response_job_at
        expect(Time.zone.at(scheduled_at)).to be_within(2.seconds).of(4.seconds.from_now)
      end
    end

    it 'rotates the schedule token when batching is enabled' do
      assistant.update!(config: { 'response_delay_seconds' => 30, 'response_batching_enabled' => true })
      token_key = format(Redis::Alfred::CAPTAIN_RESPONSE_SCHEDULE_TOKEN, conversation_id: conversation.id)

      described_class.new(conversation: conversation, assistant: assistant).schedule
      first_token = Redis::Alfred.get(token_key)

      travel 5.seconds do
        described_class.new(conversation: conversation, assistant: assistant).schedule
      end

      expect(Redis::Alfred.get(token_key)).not_to eq(first_token)
    end

    it 'does not rotate the schedule token when batching is disabled' do
      assistant.update!(config: { 'response_delay_seconds' => 30, 'response_batching_enabled' => false })
      token_key = format(Redis::Alfred::CAPTAIN_RESPONSE_SCHEDULE_TOKEN, conversation_id: conversation.id)

      described_class.new(conversation: conversation, assistant: assistant).schedule

      expect(Redis::Alfred.get(token_key)).to be_nil
    end

    it 'updates last incoming timestamp on each schedule' do
      assistant.update!(config: { 'response_delay_seconds' => 30 })
      last_incoming_key = format(Redis::Alfred::CAPTAIN_LAST_INCOMING_AT, conversation_id: conversation.id)

      freeze_time do
        described_class.new(conversation: conversation, assistant: assistant).schedule
        first_timestamp = Redis::Alfred.get(last_incoming_key).to_f

        travel 5.seconds do
          described_class.new(conversation: conversation, assistant: assistant).schedule
        end

        expect(Redis::Alfred.get(last_incoming_key).to_f).to be > first_timestamp
      end
    end
  end

  def enqueued_response_job_at
    job = enqueued_jobs.find { |entry| entry[:job] == Captain::Conversation::ResponseBuilderJob }
    job[:at]
  end

  def clear_schedule_keys
    token_key = format(Redis::Alfred::CAPTAIN_RESPONSE_SCHEDULE_TOKEN, conversation_id: conversation.id)
    last_incoming_key = format(Redis::Alfred::CAPTAIN_LAST_INCOMING_AT, conversation_id: conversation.id)
    Redis::Alfred.delete(token_key)
    Redis::Alfred.delete(last_incoming_key)
  end
end
