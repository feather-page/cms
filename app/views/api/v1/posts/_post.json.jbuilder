json.id post.public_id
json.title post.title
json.slug post.slug
json.emoji post.emoji
json.draft post.draft
json.publish_at post.publish_at&.iso8601
json.content post.content.presence || []
json.header_image_id post.header_image&.public_id
json.created_at post.created_at.iso8601
json.updated_at post.updated_at.iso8601
