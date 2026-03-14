json.data @pages, partial: "api/v1/pages/page", as: :page
json.meta do
  json.page @pagy.page
  json.pages @pagy.pages
  json.count @pagy.count
end
