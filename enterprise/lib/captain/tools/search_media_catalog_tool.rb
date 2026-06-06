class Captain::Tools::SearchMediaCatalogTool < Captain::Tools::BasePublicTool
  description 'Search the assistant media catalog for product images by name, tags, SKU, or description'
  param :query, type: 'string', desc: 'Search terms such as product name, material, or tag'

  def perform(_tool_context, query:)
    return 'Search query is required' if query.blank?

    assets = account_scoped(Captain::MediaAsset)
             .for_assistant(@assistant.id)
             .active
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
    parts.join(' | ')
  end
end
