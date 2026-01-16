# Feather-Page CMS

[![RSpec](https://github.com/feather-page/cms/actions/workflows/rspec.yml/badge.svg)](https://github.com/feather-page/cms/actions/workflows/rspec.yml)
[![Coverage Status](https://coveralls.io/repos/github/feather-page/cms/badge.svg?branch=main)](https://coveralls.io/github/feather-page/cms?branch=main)

Feather-Page CMS is a Ruby on Rails application that provides a web interface for managing small static websites. It leverages Hugo to build static sites and provides a simple management UI.

## Design Goals

*   A simple interface that can be used by non-technical users.
*   Website should look like a real web-developer hand-coded them.
*   Deployed websites should be static.
*   Deployed websites should NOT load any external resources.
*   Deployed websites should be as small as possible.
*   Deployed websites should be SEO friendly.
*   Deployed websites are on domains that belong to the user.

## Requirements

*   **Ruby**: 4.0.1 (as specified in `Gemfile`)
*   **Node.js & npm**: Required for JavaScript assets and Jest tests.
*   **System Dependencies**:
    *   `hugo`: The static site generator.
    *   `rclone`: Used for syncing files to deployment targets.
    *   `libvips`: Image processing library.
    *   `PostgreSQL`: Database.

## Setup

1.  **Install system dependencies**:
    ```bash
    brew install rclone hugo libvips postgresql
    ```

2.  **Install Ruby dependencies**:
    ```bash
    bundle install
    ```

3.  **Install JavaScript dependencies**:
    ```bash
    npm install
    ```

4.  **Prepare the database**:
    ```bash
    cp .env.example .env # Configure your database credentials
    rails db:create
    rails db:schema:load
    ```
    Alternatively, you can use:
    ```bash
    bin/setup
    ```

## Running the Application

To start the Rails server along with background workers (Sidekiq) and other services:

```bash
foreman start
```

Or start just the Rails server:
```bash
bin/dev
# or
rails s
```

## Environment Variables

| Variable | Description | Default/Example |
|----------|-------------|-----------------|
| `BASE_HOSTNAME_AND_PORT` | Base domain for staging URLs | `localhost:3000` |
| `HTTPS` | Whether to use HTTPS | `false` |
| `POSTGRES_HOST` | Database host | `localhost` |
| `POSTGRES_USERNAME` | Database username | `postgres` |
| `POSTGRES_PASSWORD` | Database password | `postgres` |
| `SMTP_ADDRESS` | Mail server address | `localhost` |
| `SMTP_PORT` | Mail server port | `1025` |
| `STAGING_SITES_PATH` | Path where staging sites are built | (Defined in Kamal/Production) |

## Scripts

*   `bin/setup`: Automated setup and database preparation.
*   `bin/dev`: Starts the Rails server.
*   `npm run lint`: Runs JavaScript linting (standard).
*   `bundle exec rubocop`: Runs Ruby linting.

## Testing

### Ruby Tests (RSpec)
```bash
bundle exec rspec
```

### JavaScript Tests (Jest)
```bash
npm test
```

## Project Structure

*   `app/interactions/`: Business logic organized using the `LightService` gem.
*   `app/components/`: Reusable UI elements using `ViewComponent`.
*   `app/javascript/`: Modern JavaScript using Import Maps.
*   `spec/`: Comprehensive test suite (RSpec and Jest).
*   `config/deploy.yml`: Kamal deployment configuration.

## Deployment

This project uses [Kamal](https://kamal-deploy.org/) for deployment.

```bash
kamal lock release -d production
kamal envify -d production
kamal accessory boot all -d production
kamal deploy -d production
```

## License

TODO: Add license information.
