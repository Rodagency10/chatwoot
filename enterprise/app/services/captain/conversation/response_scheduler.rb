class Captain::Conversation::ResponseScheduler
  SCHEDULE_BUFFER_SECONDS = 60
  MAX_RESPONSE_DELAY_SECONDS = 300

  def initialize(conversation:, assistant:, attachment_wait: 0)
    @conversation = conversation
    @assistant = assistant
    @attachment_wait = attachment_wait.to_i
  end

  def schedule
    wait_seconds = compute_wait_seconds
    triggered_at = Time.current
    touch_last_incoming(triggered_at, wait_seconds)

    schedule_token = rotate_schedule_token(wait_seconds)

    enqueue_response(wait_seconds, schedule_token: schedule_token, triggered_at: triggered_at)
  end

  private

  def compute_wait_seconds
    [@attachment_wait, @assistant.response_delay_seconds].max
  end

  def touch_last_incoming(timestamp, wait_seconds)
    key = format(::Redis::Alfred::CAPTAIN_LAST_INCOMING_AT, conversation_id: @conversation.id)
    ::Redis::Alfred.setex(key, timestamp.to_f.to_s, ttl_for(wait_seconds))
  end

  def rotate_schedule_token(wait_seconds)
    token = SecureRandom.uuid
    key = format(::Redis::Alfred::CAPTAIN_RESPONSE_SCHEDULE_TOKEN, conversation_id: @conversation.id)
    ::Redis::Alfred.setex(key, token, ttl_for(wait_seconds))
    token
  end

  def ttl_for(wait_seconds)
    wait_seconds + SCHEDULE_BUFFER_SECONDS
  end

  def enqueue_response(wait_seconds, schedule_token:, triggered_at:)
    job = Captain::Conversation::ResponseBuilderJob
    job = job.set(wait: wait_seconds.seconds) if wait_seconds.positive?

    job.perform_later(
      @conversation,
      @assistant,
      schedule_token: schedule_token,
      triggered_at: triggered_at
    )
  end
end
