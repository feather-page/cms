### Project Guidelines

#### Build & Configuration
Feather-Page CMS requires several system dependencies for building and deploying static sites.

1.  **System Dependencies**:
    *   `rclone`: Used for syncing files to deployment targets.
    *   `hugo`: The static site generator used to build the final sites.
    *   `libvips`: Image processing library.
2.  **Ruby & Node**:
    *   Ruby version: `4.0.1` (specified in README).
    *   Node.js and npm are required for JavaScript assets and testing.
3.  **Setup**:
    ```bash
    bundle install
    npm install
    rails db:create
    rails db:schema:load
    ```

#### Testing
The project uses both RSpec for Ruby and Jest for JavaScript.

1.  **Ruby Tests (RSpec)**:
    *   Run all tests: `bundle exec rspec`
    *   Run a specific file: `bundle exec rspec spec/models/page_spec.rb`
    *   **Adding a test**: Place files in `spec/` following the Rails convention.
    *   **Example**:
        ```ruby
        require 'rails_helper'

        RSpec.describe "UserInteraction", type: :model do
          it "successfully performs a basic assertion" do
            expect(1 + 1).to eq(2)
          end
        end
        ```

2.  **JavaScript Tests (Jest)**:
    *   Run all tests: `npm test`
    *   Run a specific file: `npx jest spec/javascript/your_test.spec.js`
    *   **Adding a test**: Place files in `spec/javascript/` with `.spec.js` suffix.
    *   **Example**:
        ```javascript
        describe('BasicMath', () => {
          test('adds 1 + 1 to equal 2', () => {
            expect(1 + 1).toBe(2)
          })
        })
        ```

#### Development & Code Style
1.  **Ruby Linting**:
    *   Uses RuboCop. Configuration is in `.rubocop.yml`.
    *   Check style: `bundle exec rubocop`
2.  **JavaScript Linting**:
    *   Uses `standard`.
    *   Check style: `npm run lint`
3.  **Service Objects / Interactions**:
    *   Business logic is organized using the `LightService` gem.
    *   Located in `app/interactions/`.
    *   Organizers (e.g., `Sites::CreateSite`) orchestrate multiple Actions (e.g., `SaveSite`, `AddHomePage`).
4.  **UI Components**:
    *   Uses `ViewComponent` for reusable UI elements.
    *   Located in `app/components/`.
5.  **Environment Variables**:
    *   Ensure `BASE_HOSTNAME_AND_PORT` is set for staging URL generation.
