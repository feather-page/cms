Feature: Book Block in Editor
  As a content editor
  I want to embed books from my catalog into posts
  So that I can reference books I've read in my blog content

  Background:
    Given I am logged in
    And I have a site "My Blog"
    And a book "The Great Gatsby" exists for "My Blog"
    And a book "To Kill a Mockingbird" exists for "My Blog"

  @javascript
  Scenario: Add a book block to a post
    When I go to the posts page for "My Blog"
    And I click "New Post"
    And I add a book block
    Then I should see the book search with recent books
    When I select the book "The Great Gatsby"
    Then I should see the book preview for "The Great Gatsby"

  @javascript
  Scenario: Search for a book in the book block
    When I go to the posts page for "My Blog"
    And I click "New Post"
    And I add a book block
    And I search for "Mockingbird" in the book block
    Then I should see "To Kill a Mockingbird" in the book results
    When I select the book "To Kill a Mockingbird"
    Then I should see the book preview for "To Kill a Mockingbird"

  @javascript
  Scenario: Change selected book in block
    When I go to the posts page for "My Blog"
    And I click "New Post"
    And I add a book block
    And I select the book "The Great Gatsby"
    And I click "Change" in the book block
    Then I should see the book search with recent books
    When I select the book "To Kill a Mockingbird"
    Then I should see the book preview for "To Kill a Mockingbird"

  @javascript
  Scenario: Save post with book block
    When I go to the posts page for "My Blog"
    And I click "New Post"
    And I enter the title "My Book Review"
    And I add a book block
    And I select the book "The Great Gatsby"
    And I wait for the editor to save
    And I click "Create Post"
    Then the post "My Book Review" should exist
    And the post should contain a book block for "The Great Gatsby"
