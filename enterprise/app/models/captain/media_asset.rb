class Captain::MediaAsset < ApplicationRecord
  self.table_name = 'captain_media_assets'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  has_one_attached :image

  validates :name, presence: true
  validates :currency, presence: true
  validate :validate_image_attachment, if: -> { image.attached? }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }
  scope :for_assistant, ->(assistant_id) { where(assistant_id: assistant_id) }

  scope :search, lambda { |query|
    return all if query.blank?

    sanitized_query = "%#{ActiveRecord::Base.sanitize_sql_like(query.to_s)}%"
    where(
      'captain_media_assets.name ILIKE :query OR captain_media_assets.description ILIKE :query OR ' \
      'captain_media_assets.sku ILIKE :query OR captain_media_assets.tags::text ILIKE :query',
      query: sanitized_query
    )
  }

  def price_formatted
    return nil if price_cents.blank?

    format('%.2f %s', price_cents / 100.0, currency)
  end

  def build_caption(assistant)
    template = assistant.config['media_catalog_caption_template'].presence || '{name}'
    include_price = assistant.config['media_catalog_include_price_in_caption'] != false

    caption = template.gsub('{name}', name.to_s)
    caption = caption.gsub('{price}', price_formatted.to_s) if include_price && price_formatted.present?
    caption = caption.gsub('{sku}', sku.to_s) if sku.present?
    caption.squish.presence || name
  end

  def tag_list
    Array(tags).map(&:to_s)
  end

  private

  def validate_image_attachment
    return if image.blob.content_type.to_s.start_with?('image/')

    errors.add(:image, 'must be an image file')
  end
end
