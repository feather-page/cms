# README

[![RSpec](https://github.com/feather-page/cms/actions/workflows/rspec.yml/badge.svg)](https://github.com/feather-page/cms/actions/workflows/rspec.yml)
[![Coverage Status](https://coveralls.io/repos/github/feather-page/cms/badge.svg?branch=main)](https://coveralls.io/github/feather-page/cms?branch=main)


Feather-Page CMS is a Rails application that provides a web interface for managing small static websites.

## Design Goals

* A simple interface that can be used by non-technical users.
* Website should look like a real web-developer hand-coded them.
* Deployed websites should be static.
* Deployed websites should NOT load any external resources.
* Deployed websites should be as small as possible.
* Deployed websites should be SEO friendly.
* Deployed websites are on domains that belong to the user.

## Installation

```bash
# Install dependencies
brew install rclone
brew install hugo
brew install libvips

# Install Ruby with a version manager of your choice.
rbenv install 3.4.1
rbenv local 3.4.1

# Install GEMs.
bundle install

# Create databases
rails db:create
rails db:schema:load

# Start the application.
foreman start
```

## Testing

```bash
rspec
```

# Deployment

```bash
kamal lock release -d production
kamal envify -d production
kamal accessory boot all -d production
kamal deploy -d production
```
