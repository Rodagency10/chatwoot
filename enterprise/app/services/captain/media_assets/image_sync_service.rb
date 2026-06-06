class Captain::MediaAssets::ImageSyncService
  MAX_IMAGES = 10
  MAX_FILE_BYTES = 10_000_000

  pattr_initialize [:media_asset!, :params!, { require_images: false }]

  def sync_on_create!
    attach_new_images
    ensure_primary!
    validate_presence! if require_images
  end

  def sync_on_update!
    remove_images
    update_existing_images
    attach_new_images
    set_primary_from_param
    ensure_primary!
    validate_presence!
  end

  private

  def attach_new_images
    files = Array(params[:new_images]).compact
    return if files.blank?

    next_position = media_asset.images.maximum(:position).to_i + 1
    labels = Array(params[:image_labels])

    files.each_with_index do |uploaded_file, index|
      raise Captain::MediaAssets::ImageSyncService::Error, 'Image limit reached' if media_asset.images.count >= MAX_IMAGES

      validate_upload!(uploaded_file)

      image = media_asset.images.create!(
        position: next_position + index,
        label: labels[index].presence,
        is_primary: media_asset.images.none? && index.zero?
      )
      image.file.attach(uploaded_file)
    end
  end

  def remove_images
    ids = Array(params[:removed_image_ids]).map(&:to_i).compact
    return if ids.blank?

    media_asset.images.where(id: ids).find_each(&:destroy)
  end

  def update_existing_images
    Array(params[:image_updates]).each do |update|
      image = media_asset.images.find_by(id: update[:id])
      next if image.blank?

      image.update!(label: update[:label]) if update.key?(:label)
      image.update!(position: update[:position]) if update.key?(:position)
    end
  end

  def set_primary_from_param
    primary_id = params[:primary_image_id]
    return if primary_id.blank?

    image = media_asset.images.find_by(id: primary_id)
    return if image.blank?

    media_asset.images.update_all(is_primary: false) # rubocop:disable Rails/SkipsModelValidations
    image.update!(is_primary: true)
  end

  def ensure_primary!
    return if media_asset.images.none?

    return if media_asset.images.exists?(is_primary: true)

    media_asset.images.ordered.first.update!(is_primary: true)
  end

  def validate_presence!
    return if media_asset.images.exists?

    raise Captain::MediaAssets::ImageSyncService::Error, 'At least one image is required'
  end

  def validate_upload!(uploaded_file)
    content_type = uploaded_file.content_type.to_s
    raise Captain::MediaAssets::ImageSyncService::Error, 'File must be an image' unless content_type.start_with?('image/')
    raise Captain::MediaAssets::ImageSyncService::Error, 'Image exceeds 10 MB limit' if uploaded_file.size.to_i > MAX_FILE_BYTES
  end

  class Error < StandardError; end
end
