class Captain::Tools::SearchMediaCatalogTool < Captain::Tools::BasePublicTool
  description 'Search the assistant media catalog for product images by name, tags, SKU, or description'
  param :query, type: 'string', desc: 'Search terms such as product name, material, or tag'

  def perform(_tool_context, query:)
    return 'Search query is required' if query.blank?

    assets = account_scoped(Captain::MediaAsset)
             .for_assistant(@assistant.id)
             .active
             .includes(images: { file_attachment: :blob })
             .search(query)
             .ordered
             .limit(10)

    return "No matching catalog items found for: #{query}" if assets.blank?

    log_tool_usage('search_media_catalog', { query: query, count: assets.size })
    format_assets(assets)
  end

  private

  def format_assets(assets)
    assets.map { |asset| format_asset(asset) }.join("\n")
  end

  def format_asset(asset)
    parts = ["ID: #{asset.id}", "Name: #{asset.name}"]
    parts << "SKU: #{asset.sku}" if asset.sku.present?
    parts << "Price: #{asset.price_formatted}" if asset.price_formatted.present?
    parts << "Tags: #{asset.tag_list.join(', ')}" if asset.tag_list.any?
    parts << "Description: #{asset.description}" if asset.description.present?
    parts << format_images(asset)
    parts.join(' | ')
  end

  def format_images(asset)
    images = asset.images.ordered
    return 'Images: 0' if images.blank?

    primary = asset.primary_image
    labels = images.map do |image|
      label = image.label.presence || "view_#{image.position + 1}"
      primary_marker = image.id == primary&.id ? ' (primary)' : ''
      "#{image.position + 1}:#{label}#{primary_marker}"
    end

    hint = 'send primary by default; use image_index or image_label for a specific view; ' \
           'send_all only on explicit customer request'
    "Images: #{images.size} [#{labels.join(', ')}] - #{hint}"
  end
end
