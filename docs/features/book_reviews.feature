Feature: Book Reviews
  As a site owner
  I want to write reviews for books in my catalog
  So that I can share my thoughts about books on my blog

  Background:
    Given I am logged in
    And I have a site "My Blog"
    And a book "Clean Code" exists for "My Blog"

  # Short reviews (under 300 characters) don't require title and slug
  # Long reviews (300+ characters) show title and slug fields
  @javascript
  Scenario: Create a short review without title
    When I go to the books page for "My Blog"
    And I click "Write Review" for "Clean Code"
    And I set the rating to 5 stars
    And I enter review content "Great book, highly recommended!"
    And I click "Create Review"
    Then the review should exist as a post
    And the review should be linked to "Clean Code"
    And the review should have no title

  @javascript
  Scenario: Create a long review with title
    When I go to the books page for "My Blog"
    And I click "Write Review" for "Clean Code"
    And I set the rating to 5 stars
    And I enter a review content with more than 300 characters
    Then the title field should appear
    And the title should be pre-filled with "Review: Clean Code"
    When I change the title to "Why Clean Code Changed My Life"
    And I click "Create Review"
    Then the review should exist as a post
    And the review should have the title "Why Clean Code Changed My Life"
    And the review should be linked to "Clean Code"

  @javascript
  Scenario: Edit an existing review
    Given a review "My Review" with 3 stars exists for "Clean Code"
    When I go to the books page for "My Blog"
    And I click "Edit Review" for "Clean Code"
    And I change the title to "Updated Review Title"
    And I set the rating to 5 stars
    And I change the review content to "Even better on second read..."
    And I click "Update Review"
    Then the review should have the title "Updated Review Title"
    And the review should have 5 stars

  @javascript
  Scenario: Delete a review from book list
    Given a review exists for "Clean Code"
    When I go to the books page for "My Blog"
    And I click "Edit Review" for "Clean Code"
    And I click "Delete Review"
    And I confirm the deletion
    Then the review should no longer exist
    And I should see "Write Review" for "Clean Code"

  @javascript
  Scenario: Delete a review from posts list
    Given a review "My Clean Code Review" exists for "Clean Code"
    When I go to the posts page for "My Blog"
    And I delete the post "My Clean Code Review"
    Then the review should no longer exist
    When I go to the books page for "My Blog"
    Then I should see "Write Review" for "Clean Code"

  Scenario: Review appears in blog post list
    Given a review "My Clean Code Review" exists for "Clean Code"
    When I go to the posts page for "My Blog"
    Then I should see "My Clean Code Review" in the posts list

  Scenario: Short review appears in blog post list
    Given a short review with 4 stars exists for "Clean Code"
    When I go to the posts page for "My Blog"
    Then I should see a review for "Clean Code" in the posts list

  Scenario: Only one review per book
    Given a review exists for "Clean Code"
    When I go to the books page for "My Blog"
    Then I should not see "Write Review" for "Clean Code"
    And I should see "Edit Review" for "Clean Code"

  Scenario: Star rating is displayed on generated website
    Given a review "Amazing Book" with 4 stars exists for "Clean Code"
    When the site is built with Hugo
    Then the generated post should display 4 stars
    And the stars should be visible as "★★★★☆"
