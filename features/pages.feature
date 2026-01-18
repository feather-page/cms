Feature: Page Management
  As a site owner
  I want to create and manage static pages
  So that I can have permanent content on my website

  Background:
    Given I am logged in
    And I have a site "My Blog"

  @javascript
  Scenario: Create a new page
    When I go to the pages list for "My Blog"
    And I click "New Page"
    And I enter the page title "About Me"
    And I enter the page slug "/about"
    And I click "Create Page"
    Then the page "About Me" should exist
    And I should see "About Me" in the pages list

  @javascript
  Scenario: Create homepage
    When I go to the pages list for "My Blog"
    And I click "New Page"
    And I enter the page title "Welcome"
    And I enter the page slug "/"
    And I click "Create Page"
    Then the homepage should exist

  @javascript
  Scenario: Edit an existing page
    Given a page "Contact" exists for "My Blog"
    When I edit the page "Contact"
    And I change the page title to "Get in Touch"
    And I click "Update Page"
    Then the page should have the title "Get in Touch"

  @javascript
  Scenario: Delete a page
    Given a page "Old Page" exists for "My Blog"
    When I go to the pages list for "My Blog"
    And I delete the page "Old Page"
    Then the page "Old Page" should no longer exist

  @javascript
  Scenario: Add page to navigation
    Given a page "Services" exists for "My Blog"
    When I edit the page "Services"
    And I check "Add to navigation"
    And I click "Update Page"
    Then the page "Services" should be in the navigation

  Scenario: View pages list with pagination
    Given 25 pages exist for "My Blog"
    When I go to the pages list for "My Blog"
    Then I should see pagination controls
