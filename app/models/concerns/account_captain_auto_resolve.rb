module AccountCaptainAutoResolve
  extend ActiveSupport::Concern

  VALID_CAPTAIN_AUTO_RESOLVE_MODES = %w[evaluated legacy disabled].freeze
  DEFAULT_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES = 60
  MIN_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES = 5
  MAX_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES = 10_080

  included do
    VALID_CAPTAIN_AUTO_RESOLVE_MODES.each do |mode|
      define_method("captain_auto_resolve_#{mode}?") do
        captain_auto_resolve_mode == mode
      end
    end

    validates :captain_auto_resolve_after_minutes,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: MIN_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES,
                less_than_or_equal_to: MAX_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES,
                allow_nil: true
              },
              if: :validate_captain_auto_resolve_after_minutes?
  end

  def captain_auto_resolve_mode
    mode = settings&.[]('captain_auto_resolve_mode')
    return mode if VALID_CAPTAIN_AUTO_RESOLVE_MODES.include?(mode)
    return 'disabled' if settings&.[]('captain_disable_auto_resolve') == true

    feature_enabled?('captain_tasks') ? 'evaluated' : 'legacy'
  end

  def captain_auto_resolve_after_minutes
    minutes = settings&.[]('captain_auto_resolve_after_minutes')
    return DEFAULT_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES if minutes.nil?

    minutes.to_i.clamp(MIN_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES, MAX_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES)
  end

  def captain_auto_resolve_after_minutes=(minutes)
    normalized = if minutes.nil? || minutes == ''
                   nil
                 else
                   minutes.to_i.clamp(MIN_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES, MAX_CAPTAIN_AUTO_RESOLVE_AFTER_MINUTES)
                 end

    self.settings = (settings || {}).merge('captain_auto_resolve_after_minutes' => normalized)
  end

  def captain_auto_resolve_inactivity_duration
    captain_auto_resolve_after_minutes.minutes
  end

  private

  def validate_captain_auto_resolve_after_minutes?
    return false unless settings.is_a?(Hash)

    settings.key?('captain_auto_resolve_after_minutes') && !settings['captain_auto_resolve_after_minutes'].nil?
  end
end
