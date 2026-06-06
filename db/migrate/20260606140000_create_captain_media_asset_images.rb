class CreateCaptainMediaAssetImages < ActiveRecord::Migration[7.1]
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
    media_asset_model = Class.new(ApplicationRecord) do
      self.table_name = 'captain_media_assets'
      has_one_attached :image
    end

    image_model = Class.new(ApplicationRecord) do
      self.table_name = 'captain_media_asset_images'
      has_one_attached :file
    end

    media_asset_model.find_each do |asset|
      next unless asset.image.attached?

      image_record = image_model.create!(
        media_asset_id: asset.id,
        position: 0,
        label: 'primary',
        is_primary: true
      )
      image_record.file.attach(asset.image.blob)
      asset.image.purge
    end
  end
end
