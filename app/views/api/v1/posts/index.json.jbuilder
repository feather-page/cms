json.data @posts, partial: "api/v1/posts/post", as: :post
json.meta do
  json.page @pagy.page
  json.pages @pagy.pages
  json.count @pagy.count
end
