class CreateCaptainMediaAssetImages < ActiveRecord::Migration[7.1]
  LEGACY_RECORD_TYPE = 'Captain::MediaAsset'
  IMAGE_RECORD_TYPE = 'Captain::MediaAssetImage'

  def up
    create_table :captain_media_asset_images do |t|
      t.references :media_asset, null: false, foreign_key: { to_table: :captain_media_assets }, index: true
      t.integer :position, null: false, default: 0
      t.string :label
      t.boolean :is_primary, null: false, default: false
      t.timestamps
    end

    add_index :captain_media_asset_images, [:media_asset_id, :position], name: 'index_captain_media_asset_images_on_asset_and_position'

    migrate_legacy_single_images
  end

  def down
    drop_table :captain_media_asset_images
  end

  private

  def migrate_legacy_single_images
    return unless active_storage_ready?

    legacy_attachments.find_each do |attachment|
      image_id = insert_image_record(attachment.record_id)
      move_attachment_to_image(attachment.id, image_id)
    end
  end

  def active_storage_ready?
    table_exists?(:active_storage_attachments) && table_exists?(:captain_media_assets)
  end

  def legacy_attachments
    ActiveStorage::Attachment.where(record_type: LEGACY_RECORD_TYPE, name: 'image')
  end

  def insert_image_record(media_asset_id)
    connection.select_value(<<~SQL.squish)
      INSERT INTO captain_media_asset_images (media_asset_id, position, label, is_primary, created_at, updated_at)
      VALUES (#{connection.quote(media_asset_id)}, 0, 'primary', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      RETURNING id
    SQL
  end

  def move_attachment_to_image(attachment_id, image_id)
    ActiveStorage::Attachment.where(id: attachment_id).update_all( # rubocop:disable Rails/SkipsModelValidations
      record_type: IMAGE_RECORD_TYPE,
      record_id: image_id,
      name: 'file'
    )
  end
end
