class Captain::MediaAssetImage < ApplicationRecord
  self.table_name = 'captain_media_asset_images'

  belongs_to :media_asset, class_name: 'Captain::MediaAsset'
  has_one_attached :file

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :validate_file_attachment, if: -> { file.attached? }

  scope :ordered, -> { order(position: :asc, id: :asc) }

  def display_label
    label.presence || "view_#{position + 1}"
  end

  private

  def validate_file_attachment
    return if file.blob.content_type.to_s.start_with?('image/')

    errors.add(:file, 'must be an image file')
  end
end
