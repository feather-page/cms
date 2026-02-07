# Content API step definitions

# ─────────────────────────────────────────────────────────────
# Background / Setup
# ─────────────────────────────────────────────────────────────

Given("I have a user with an API token") do
  @current_user = create(:user)
  @api_token = create(:api_token, user: @current_user)
  api.auth_header(@api_token.plain_token)
end

Given("the user has a site {string}") do |site_title|
  @current_site = create(:site, title: site_title)
  create(:site_user, site: @current_site, user: @current_user)
end

Given("another user has a site {string}") do |site_title|
  other_user = create(:user)
  create(:site, title: site_title).tap do |site|
    create(:site_user, site: site, user: other_user)
  end
end

# ─────────────────────────────────────────────────────────────
# Authentication
# ─────────────────────────────────────────────────────────────

When("I send a GET request to the posts endpoint without authentication") do
  api.clear_auth
  api.json_request(:get, site_posts_path)
end

When("I send a GET request to the posts endpoint with an invalid token") do
  api.auth_header("invalid-token-value")
  api.json_request(:get, site_posts_path)
end

When("I try to access posts for site {string}") do |site_title|
  site = Site.find_by!(title: site_title)
  api.json_request(:get, "/api/v1/sites/#{site.public_id}/posts")
end

# ─────────────────────────────────────────────────────────────
# Posts
# ─────────────────────────────────────────────────────────────

Given("the site has {int} posts") do |count|
  count.times { create(:post, site: @current_site) }
end

Given("the site has a post {string}") do |title|
  @current_post = create(:post, site: @current_site, title: title)
end

When("I send a GET request to the posts endpoint") do
  api.json_request(:get, site_posts_path)
end

When("I create a post with title {string} and content:") do |title, content_json|
  body = { post: { title: title, content: JSON.parse(content_json) } }
  api.json_request(:post, site_posts_path, body)
end

When("I create a post with all supported block types") do
  image = create(:image, site: @current_site)
  content = [
    { type: "paragraph", text: "Hello" },
    { type: "header", text: "Title", level: 2 },
    { type: "code", code: "x = 1", language: "ruby" },
    { type: "image", image_id: image.public_id },
    { type: "quote", text: "To be", caption: "Shakespeare" },
    { type: "list", style: "ul", items: %w[one two] },
    { type: "table", content: [%w[A B], %w[1 2]], with_headings: true },
    { type: "book", book_public_id: "abc123" }
  ]
  body = { post: { title: "All Block Types", content: content } }
  api.json_request(:post, site_posts_path, body)
end

When("I update the post with title {string}") do |title|
  path = "#{site_posts_path}/#{@current_post.public_id}"
  api.json_request(:patch, path, { post: { title: title } })
end

When("I update the post with content:") do |content_json|
  path = "#{site_posts_path}/#{@current_post.public_id}"
  api.json_request(:patch, path, { post: { content: JSON.parse(content_json) } })
end

When("I delete the post") do
  @deleted_post_id = @current_post.id
  path = "#{site_posts_path}/#{@current_post.public_id}"
  api.json_request(:delete, path)
end

# ─────────────────────────────────────────────────────────────
# Pages
# ─────────────────────────────────────────────────────────────

Given("the site has {int} pages") do |count|
  count.times { create(:page, site: @current_site) }
end

Given("the site has a page {string}") do |title|
  @current_page = create(:page, site: @current_site, title: title)
end

When("I send a GET request to the pages endpoint") do
  api.json_request(:get, site_pages_path)
end

When("I create a page with title {string} and content:") do |title, content_json|
  body = { page: { title: title, slug: title.parameterize, page_type: "default", content: JSON.parse(content_json) } }
  api.json_request(:post, site_pages_path, body)
end

When("I update the page with title {string}") do |title|
  path = "#{site_pages_path}/#{@current_page.public_id}"
  api.json_request(:patch, path, { page: { title: title } })
end

When("I delete the page") do
  path = "#{site_pages_path}/#{@current_page.public_id}"
  api.json_request(:delete, path)
end

# ─────────────────────────────────────────────────────────────
# Images
# ─────────────────────────────────────────────────────────────

Given("the site has an image") do
  @current_image = create(:image, site: @current_site)
end

When("I send a GET request to the image endpoint") do
  api.json_request(:get, "#{site_images_path}/#{@current_image.public_id}")
end

# ─────────────────────────────────────────────────────────────
# Response Assertions
# ─────────────────────────────────────────────────────────────

Then("the response status should be {int}") do |status|
  expect(api_response.status).to eq(status)
end

Then("the response should contain error {string}") do |error_message|
  expect(api_json["error"]).to eq(error_message)
end

Then("the response should contain message {string}") do |message|
  expect(api_json["message"]).to eq(message)
end

Then("the response should contain {int} posts") do |count|
  expect(api_json["data"].size).to eq(count)
end

Then("the response should contain {int} pages") do |count|
  expect(api_json["data"].size).to eq(count)
end

Then("the response should contain post title {string}") do |title|
  expect(api_json.dig("data", "title")).to eq(title)
end

Then("the response should contain page title {string}") do |title|
  expect(api_json.dig("data", "title")).to eq(title)
end

Then("the post content should have validated blocks") do
  content = api_json.dig("data", "content")
  expect(content).to be_an(Array)
  expect(content).not_to be_empty
  content.each { |block| expect(block).to have_key("id") }
end

Then("the response content should contain {int} blocks") do |count|
  content = api_json.dig("data", "content")
  expect(content.size).to eq(count)
end

Then("the post should no longer exist") do
  expect(Post.find_by(id: @deleted_post_id)).to be_nil
end

Then("the error details should list valid block types") do
  details = api_json.dig("details", "content")
  expect(details).to be_present
  expect(details.first).to include("Valid types:")
end

Then("the error should specify block index {int}") do |index|
  details = api_json.dig("details", "content")
  expect(details).to be_present
  expect(details.first).to include("Block #{index}")
end

Then("the error should specify block type {string}") do |type|
  details = api_json.dig("details", "content")
  expect(details).to be_present
  expect(details.first).to include("(#{type})")
end

# ─────────────────────────────────────────────────────────────
# OpenAPI Schema Validation
# ─────────────────────────────────────────────────────────────

Then("the response should match the OpenAPI schema for {string} with status {int}") do |operation, status|
  method_name, path_template = operation.split(" ", 2)
  resolved = resolve_operation_schema(method_name, path_template, status)
  errors = SchemaValidator.validate(api_json, resolved)

  expect(errors).to be_empty, lambda {
    msgs = errors.map { |e| "#{e['data_pointer']}: #{e['error']}" }
    "Schema mismatch:\n#{msgs.join("\n")}\n\nBody: #{api_json}"
  }
end

def resolve_operation_schema(method_name, path_template, status)
  openapi = YAML.load_file(Rails.root.join("docs/api/openapi.yml"))
  path_key = path_template.start_with?("/") ? path_template : "/#{path_template}"
  op = openapi.dig("paths", path_key, method_name.downcase)
  raise "No spec for #{method_name} #{path_template}" unless op

  raw = op.dig("responses", status.to_s, "content", "application/json", "schema")
  raise "No schema for #{method_name} #{path_template} #{status}" unless raw

  resolve_openapi_schema(raw, openapi)
end

def resolve_openapi_schema(schema, spec)
  return resolve_ref(schema, spec) if schema["$ref"]

  result = schema.dup
  result["oneOf"] = result["oneOf"].map { |s| resolve_openapi_schema(s, spec) } if result["oneOf"]
  result["items"] = resolve_openapi_schema(result["items"], spec) if result["items"]
  resolve_openapi_properties(result, spec)
end

def resolve_ref(schema, spec)
  path = schema["$ref"].delete_prefix("#/").split("/")
  resolve_openapi_schema(spec.dig(*path), spec)
end

def resolve_openapi_properties(result, spec)
  if result["properties"]
    result["properties"] = result["properties"].transform_values { |v| resolve_openapi_schema(v, spec) }
  end
  if result["additionalProperties"].is_a?(Hash)
    result["additionalProperties"] = resolve_openapi_schema(result["additionalProperties"], spec)
  end
  result
end
