# Content API

Generic CRUD REST API for managing posts, pages, and images. Designed for AI-driven content import (e.g. from Jekyll) but reusable for any integration.

## Overview

- **Authentication:** Bearer token (`Authorization: Bearer <token>`), created with
  `mix feather.api_token EMAIL [NAME]`; only its SHA-256 digest is stored
- **Authorization:** the token's user must have access to the site (super admin or member);
  other sites answer 404 like missing ones
- **Content validation:** Block content validated against the block schemas of the OpenAPI spec
- **Error messages:** AI-friendly, with block index, type, and field-level detail
- **Pagination:** list endpoints return 20 records per page, selected with `?p=`, and a `meta`
  object (`page`, `pages`, `count`)
- **Publishing:** posts and pages are read with their unpublished changes. Creating or updating
  one publishes it at once (no deploy), unless the request sends `draft: true`, which stores the
  changes and makes it a draft (unpublished if it was published). `draft` in a response means
  the record has no published version

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
| POST | `/api/v1/sites/:site_id/images` | Create an image from a multipart `file` or a `url` |
| GET | `/api/v1/sites/:site_id/images/:id` | Show image metadata |

## Block Types

Content is stored as an array of typed blocks. Each block is validated against its JSON Schema defined in `docs/api/openapi.yml`:

- **paragraph** - Text with optional formatting
- **header** - Heading level 2-4
- **code** - Code with language
- **image** - Image reference with caption
- **quote** - Blockquote with attribution
- **list** - Ordered or unordered
- **table** - Rows with optional header
- **embed** - Embedded media (service, source, size, caption)
- **book** - Book reference from catalog

Inline HTML (paragraph, header and quote text, captions, list items, table cells) is
sanitized when content is stored, so responses return the sanitized HTML, not the input
verbatim: only `b`, `i`, `u`, `a` (with a relative, `http`, `https`, `mailto` or `tel`
`href`), `code` and `br` survive (plus the link attributes the admin editor writes:
`target="_blank"` and `rel` with `nofollow`, `noopener` or `noreferrer`).
Other elements are removed with their text kept, `script` and `style` with their content.
Text is re-serialized like a browser's `innerHTML` (`&amp;`, `&lt;`, `&gt;`, `&nbsp;`).
Embed `source` and `embed` URLs that are not such safe link targets become `null`.

## Key Files

| File | Purpose |
|------|---------|
| `docs/api/openapi.yml` | OpenAPI 3.1.0 specification (single source of truth) |
| `lib/feather_web/router.ex` | Routes, `scope "/api/v1/sites/:site_id"` |
| `lib/feather_web/plugs/api_auth.ex` | Token authentication, loads the site through `Feather.Sites.get_site/2` |
| `lib/feather_web/controllers/api/v1/post_controller.ex` | Posts CRUD |
| `lib/feather_web/controllers/api/v1/page_controller.ex` | Pages CRUD |
| `lib/feather_web/controllers/api/v1/image_controller.ex` | Image show and creation from a file or URL |
| `lib/feather_web/controllers/api/v1/content_params.ex` | Permitted fields, content validation, image public ids |
| `lib/feather_web/controllers/api/v1/fallback_controller.ex` | Error results to JSON responses |
| `lib/feather/content/block_validator.ex` | Block schemas, validates content against them |
| `lib/feather/content/schema_validator.ex` | Lightweight JSON Schema validator (no external dependency) |
| `lib/feather/accounts/api_token.ex` | Bearer token schema |

## Architecture Decisions

- **OpenAPI as single source of truth**: Block schemas are defined in `openapi.yml`.
  `Feather.Content.BlockValidator` holds a hand port of them, and a test fails when the two
  differ
- **No external dependency for validation**: `Feather.Content.SchemaValidator` (~200 LOC)
  validates against the JSON Schema subset used by the block types
- **404, not 403**: sites the token cannot access answer 404 to avoid leaking their existence
- **Strict references**: an unknown `header_image_id` or `thumbnail_image_id` is a 422; `null` or
  `""` clears the image
- **Auto-generated block IDs**: Blocks without an `id` field get a random 10-character
  alphanumeric ID during normalization

## Testing

All response tests validate against the OpenAPI spec (`assert_openapi_response/4` in
`test/support/api_helpers.ex`):

```bash
# The API tests (authentication, posts, pages, images, the ported content_api scenarios)
mix test test/feather_web/controllers/api

# Block and schema validators, incl. the check against openapi.yml
mix test test/feather/content/block_validator_test.exs test/feather/content/schema_validator_test.exs
```
