class Captain::MediaAsset < ApplicationRecord
  self.table_name = 'captain_media_assets'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  has_many :images, class_name: 'Captain::MediaAssetImage', dependent: :destroy, inverse_of: :media_asset

  validates :name, presence: true
  validates :currency, presence: true

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

    format('%<amount>.2f %<currency>s', amount: price_cents / 100.0, currency: currency)
  end

  def build_caption(assistant, image: nil)
    template = assistant.config['media_catalog_caption_template'].presence || '{name}'
    include_price = assistant.config['media_catalog_include_price_in_caption'] != false

    caption = template.gsub('{name}', name.to_s)
    caption = caption.gsub('{price}', price_formatted.to_s) if include_price && price_formatted.present?
    caption = caption.gsub('{sku}', sku.to_s) if sku.present?

    if image.present? && image.label.present? && !image.is_primary?
      caption = "#{caption} — #{image.label}"
    end

    caption.squish.presence || name
  end

  def tag_list
    Array(tags).map(&:to_s)
  end

  def primary_image
    images.find_by(is_primary: true) || images.ordered.first
  end

  def image_for_send(image_index: nil, image_label: nil)
    return primary_image if image_index.blank? && image_label.blank?

    if image_label.present?
      normalized = image_label.to_s.downcase.strip
      images.ordered.find { |img| img.label.to_s.downcase == normalized } ||
        images.ordered.find { |img| img.display_label.downcase == normalized }
    elsif image_index.present?
      images.ordered[image_index.to_i - 1]
    end
  end

  def image_count
    images.count
  end
end
