json.payload do
  json.array! @media_assets do |media_asset|
    json.partial! 'api/v1/models/captain/media_asset', formats: [:json], resource: media_asset
  end
end

json.meta do
  json.total_count @media_assets_count
  json.page @current_page
end
