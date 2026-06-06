class CreateCaptainMediaAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_media_assets do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :assistant, null: false, foreign_key: { to_table: :captain_assistants }, index: true
      t.string :name, null: false
      t.string :sku
      t.integer :price_cents
      t.string :currency, null: false, default: 'EUR'
      t.text :description
      t.jsonb :tags, null: false, default: []
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :captain_media_assets, [:assistant_id, :active]
    add_index :captain_media_assets, :tags, using: :gin
  end
end
