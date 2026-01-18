if @image&.valid?
  json.success 1
  json.id @image.id
  json.file do
    json.url(site_image_url(current_site, @image))
  end
else
  json.success 0
end
