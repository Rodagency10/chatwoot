module Captain::Conversation::ResponseScheduleGuard
  extend ActiveSupport::Concern

  private

  def stale_response_schedule?(schedule_token, triggered_at)
    return false if schedule_token.blank? && triggered_at.blank?

    stale_schedule_token?(schedule_token) || newer_incoming_since?(triggered_at)
  end

  def stale_schedule_token?(schedule_token)
    return false if schedule_token.blank?

    token_key = format(Redis::Alfred::CAPTAIN_RESPONSE_SCHEDULE_TOKEN, conversation_id: @conversation.id)
    Redis::Alfred.get(token_key) != schedule_token
  end

  def newer_incoming_since?(triggered_at)
    return false if triggered_at.blank?

    last_incoming_key = format(Redis::Alfred::CAPTAIN_LAST_INCOMING_AT, conversation_id: @conversation.id)
    last_incoming = Redis::Alfred.get(last_incoming_key)&.to_f
    return false unless last_incoming

    normalize_triggered_at(triggered_at).to_f < last_incoming
  end

  def normalize_triggered_at(triggered_at)
    return triggered_at.in_time_zone if triggered_at.is_a?(Time)

    Time.zone.parse(triggered_at.to_s)
  end
end
