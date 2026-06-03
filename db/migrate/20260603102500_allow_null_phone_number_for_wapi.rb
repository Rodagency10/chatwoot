class AllowNullPhoneNumberForWapi < ActiveRecord::Migration[7.1]
  def up
    # Allow NULL phone_number for WAPI provider
    change_column_null :channel_whatsapp, :phone_number, true

    # Add check constraint: non-wapi providers must have a phone_number
    execute <<~SQL.squish
      ALTER TABLE channel_whatsapp
      ADD CONSTRAINT phone_number_required_for_non_wapi
      CHECK (provider = 'wapi' OR phone_number IS NOT NULL)
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE channel_whatsapp
      DROP CONSTRAINT IF EXISTS phone_number_required_for_non_wapi
    SQL

    execute 'DELETE FROM channel_whatsapp WHERE phone_number IS NULL'
    change_column_null :channel_whatsapp, :phone_number, false
  end
end
