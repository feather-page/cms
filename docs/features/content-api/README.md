# Content API

Generic CRUD REST API for managing posts, pages, and images. Designed for AI-driven content import (e.g. from Jekyll) but reusable for any integration.

## Overview

- **Authentication:** Bearer token via `ApiToken` model
- **Authorization:** Pundit policies scope access to user's sites
- **Content validation:** Block content validated against JSON Schema definitions from the OpenAPI spec
- **Error messages:** AI-friendly, with block index, type, and field-level detail

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/sites/:site_id/posts` | List all posts |
| POST | `/api/v1/sites/:site_id/posts` | Create a post |
| GET | `/api/v1/sites/:site_id/posts/:id` | Show a post |
| PATCH | `/api/v1/sites/:site_id/posts/:id` | Update a post |
| DELETE | `/api/v1/sites/:site_id/posts/:id` | Delete a post |
| GET | `/api/v1/sites/:site_id/pages` | List all pages |
| POST | `/api/v1/sites/:site_id/pages` | Create a page |
| GET | `/api/v1/sites/:site_id/pages/:id` | Show a page |
| PATCH | `/api/v1/sites/:site_id/pages/:id` | Update a page |
| DELETE | `/api/v1/sites/:site_id/pages/:id` | Delete a page |
| POST | `/api/v1/sites/:site_id/images` | Create image from URL |
| GET | `/api/v1/sites/:site_id/images/:id` | Show image metadata |
| GET | `/api/v1/schema` | OpenAPI 3.1.0 specification |

## Block Types

Content is stored as an array of typed blocks. Each block is validated against its JSON Schema defined in `docs/api/openapi.yml`:

- **paragraph** - Text with optional formatting
- **header** - Heading level 1-6
- **code** - Code with language
- **image** - Image reference with caption
- **quote** - Blockquote with attribution
- **list** - Ordered or unordered
- **table** - Rows with optional header
- **book** - Book reference from catalog

## Key Files

| File | Purpose |
|------|---------|
| `docs/api/openapi.yml` | OpenAPI 3.1.0 specification (single source of truth) |
| `app/controllers/api/v1/base_controller.rb` | Shared API logic (auth, serialization, validation) |
| `app/controllers/api/v1/posts_controller.rb` | Posts CRUD |
| `app/controllers/api/v1/pages_controller.rb` | Pages CRUD |
| `app/controllers/api/v1/images_controller.rb` | Image creation from URL |
| `app/controllers/api/v1/schema_controller.rb` | Serves OpenAPI spec |
| `app/utils/schema_validator.rb` | Lightweight JSON Schema validator (no external gem) |
| `app/utils/blocks/content_validator.rb` | Validates blocks against OpenAPI schemas |
| `app/models/api_token.rb` | Bearer token model |
| `app/policies/api_token_policy.rb` | Token authorization policy |
| `db/migrate/20260207100000_create_api_tokens.rb` | Token migration |

## Architecture Decisions

- **OpenAPI as single source of truth**: Block schemas defined once in `openapi.yml`, used by both validation and tests
- **No external gem for validation**: Custom `SchemaValidator` (~130 LOC) validates against JSON Schema subset used by block types, avoiding external dependency
- **`policy_scope` filtering**: Unauthorized sites return 404 (not 403) to avoid leaking resource existence
- **Content extracted outside strong params**: `ActionController::Parameters` cannot handle arrays of heterogeneous hashes, so content is extracted directly from raw params via `params.dig(:post, :content)`
- **Auto-generated block IDs**: Blocks without an `id` field get a random 10-character alphanumeric ID assigned during validation

## Testing

All tests validate responses against the OpenAPI spec:

```bash
# Run only API tests
bundle exec rspec spec/requests/api/

# Run content validator tests
bundle exec rspec spec/utils/blocks/content_validator_spec.rb

# Run API token model tests
bundle exec rspec spec/models/api_token_spec.rb
```
