json.id resource.id
json.label resource.label
json.position resource.position
json.is_primary resource.is_primary
json.display_label resource.display_label

if resource.file.attached?
  json.url url_for(resource.file)
  json.thumb_url url_for(resource.file)
else
  json.url nil
  json.thumb_url nil
end
