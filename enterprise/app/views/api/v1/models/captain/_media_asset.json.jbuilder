json.account_id resource.account_id
json.assistant do
  json.partial! 'api/v1/models/captain/assistant', formats: [:json], resource: resource.assistant
end
json.id resource.id
json.name resource.name
json.sku resource.sku
json.price_cents resource.price_cents
json.price_formatted resource.price_formatted
json.currency resource.currency
json.description resource.description
json.tags resource.tag_list
json.active resource.active
json.position resource.position
json.created_at resource.created_at.to_i
json.updated_at resource.updated_at.to_i

if resource.image.attached?
  json.image_url url_for(resource.image)
  json.thumb_url url_for(resource.image)
else
  json.image_url nil
  json.thumb_url nil
end
