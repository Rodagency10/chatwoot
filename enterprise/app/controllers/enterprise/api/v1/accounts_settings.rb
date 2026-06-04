module Enterprise::Api::V1::AccountsSettings
  private

  def permitted_settings_attributes
    super + [
      :captain_auto_resolve_mode,
      :captain_auto_resolve_after_minutes,
      { conversation_required_attributes: [] }
    ]
  end
end
