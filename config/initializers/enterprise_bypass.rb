Rails.application.config.after_initialize do
  ChatwootHub.define_singleton_method(:pricing_plan) { 'enterprise' }

  ChatwootHub.define_singleton_method(:pricing_plan_quantity) { 999_999 }

  ChatwootApp.define_singleton_method(:self_hosted_enterprise?) { true }
end
