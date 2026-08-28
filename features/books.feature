Feature: Book Catalog
  As a site owner
  I want to manage a book catalog
  So that I can share my reading list with visitors

  Background:
    Given I am logged in
    And I have a site "My Blog"

  @javascript
  Scenario: Mark book as finished
    Given a book "Refactoring" exists for "My Blog"
    When I edit the book "Refactoring"
    And I set the reading status to "Finished"
    And I click "Update Book"
    Then the book should be marked as "Finished"
