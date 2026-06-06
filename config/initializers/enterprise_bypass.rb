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

    # Force-enable all features on all existing accounts to unlock premium modules
    all_feature_names = YAML.safe_load(Rails.root.join('config/features.yml').read).pluck('name')
    Account.find_in_batches do |accounts|
      accounts.each do |account|
        account.enable_features!(*all_feature_names)
      end
    end
  rescue StandardError
    # DB not available yet (CI, docker build, db:create, db:schema:load, etc.) - skip silently
  end
end
