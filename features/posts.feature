Feature: Post Management
  As a site owner
  I want to create and manage blog posts
  So that I can publish content on my website

  Background:
    Given I am logged in
    And I have a site "My Blog"

  # Short posts (under 300 characters) don't require title and slug
  # Long posts (300+ characters) show title and slug fields

  @javascript
  Scenario: Create a post with title
    When I go to the posts page for "My Blog"
    And I click "New Post"
    And I enter the title "My First Post"
    And I click "Create Post"
    Then the post "My First Post" should exist
    And I should see "My First Post" in the posts list

  @javascript
  Scenario: Create a post with custom slug
    When I go to the posts page for "My Blog"
    And I click "New Post"
    And I enter the title "Hello World"
    And I enter the slug "/hello-world-2024"
    And I click "Create Post"
    Then the post should have the slug "/hello-world-2024"

  @javascript
  Scenario: Edit an existing post
    Given a post "Draft Post" exists for "My Blog"
    When I edit the post "Draft Post"
    And I change the title to "Published Post"
    And I click "Update Post"
    Then the post should have the title "Published Post"

  @javascript
  Scenario: Delete a post
    Given a post "Unwanted Post" exists for "My Blog"
    When I go to the posts page for "My Blog"
    And I delete the post "Unwanted Post"
    Then the post "Unwanted Post" should no longer exist
    And I should not see "Unwanted Post" in the posts list

  @javascript
  Scenario: Set post publish date
    Given a post "Scheduled Post" exists for "My Blog"
    When I edit the post "Scheduled Post"
    And I set the publish date to "2024-12-25"
    And I click "Update Post"
    Then the post should have publish date "2024-12-25"

  Scenario: View posts list with pagination
    Given 25 posts exist for "My Blog"
    When I go to the posts page for "My Blog"
    Then I should see pagination controls
    And I should see 20 posts on the first page
