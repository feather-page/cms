json.id page.public_id
json.title page.title
json.slug page.slug
json.emoji page.emoji
json.page_type page.page_type
json.content page.content.presence || []
json.header_image_id page.header_image&.public_id
json.created_at page.created_at.iso8601
json.updated_at page.updated_at.iso8601
