Rails.application.config.after_initialize do
  ChatwootHub.define_singleton_method(:pricing_plan) { 'enterprise' }

  ChatwootHub.define_singleton_method(:pricing_plan_quantity) { 999_999 }

  ChatwootApp.define_singleton_method(:self_hosted_enterprise?) { true }

  begin
    InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN').tap do |config|
      config.value = 'enterprise'
      config.save! if config.changed?
    end

    InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').tap do |config|
      config.value = 999_999
      config.save! if config.changed?
    end
  rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad
    # DB not available yet (e.g. during db:create in CI) — skip silently
  end
end
