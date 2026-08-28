# Feature Index

The `.feature` files are executable specification and documentation in one — see
[ADR-0001](../docs/adr/0001-bdd-feature-first-development.md).

| Feature | Description | File |
|---------|-------------|------|
| Authentication | Magic-link login, logout, token authentication | `authentication.feature` |
| Site Management | Creating and managing sites | `site_management.feature` |
| Posts | Creating, editing and publishing posts | `posts.feature` |
| Pages | Managing pages | `pages.feature` |
| Books | Managing the book catalogue | `books.feature` |
| Book Reviews | Reviews with star ratings | `book_reviews.feature` |
| Book Block | Embedding books in posts | `book_block.feature` |
| Unsplash Images | Using images from Unsplash | `unsplash_images.feature` |
| Content API | REST API for posts, pages, images | `content_api.feature` |

Projects have no Cucumber coverage — the feature is exercised by RSpec (`spec/models/project_spec.rb`,
`spec/requests/projects_controller_spec.rb`, and the component specs). The API is documented in
`docs/api/README.md` and specified in `docs/api/openapi.yml`.

## Running

```bash
bundle exec cucumber                          # everything
bundle exec cucumber features/posts.feature   # a single feature
bundle exec cucumber --tags "not @javascript" # without browser scenarios
```

Configured in `config/cucumber.yml`. `rake` runs RSpec and Cucumber together.

## Adding a feature

Add a `.feature` file in `features/`, implement the step definitions in `features/step_definitions/`,
and extend this index.
