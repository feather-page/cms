Feature: Site Management
  As a logged in user
  I want to create and manage websites
  So that I can organize my static sites

  Background:
    Given I am logged in
    And a theme "Default" exists

  @javascript
  Scenario: Create a new site
    When I go to the sites overview
    And I click "New Site"
    And I fill in "Title" with "My Blog"
    And I fill in "Domain" with "myblog.com"
    And I click "Create Site"
    Then the site "My Blog" should have been created

  @javascript
  Scenario: Edit a site
    Given a site "My Blog" exists
    When I edit the site "My Blog"
    And I fill in "Title" with "My New Blog"
    And I click "Update Site"
    Then the title "My New Blog" should be displayed

  @javascript
  Scenario: Change site emoji
    Given a site "My Blog" exists
    When I edit the site "My Blog"
    And I fill in "Emoji" with "🚀"
    And I click "Update Site"
    Then the emoji "🚀" should be displayed

  @javascript
  Scenario: Change site theme
    Given a site "My Blog" exists
    And another theme "Modern" exists
    When I edit the site "My Blog"
    And I select "Modern" from "Theme"
    And I click "Update Site"
    Then the theme "Modern" should be active

  Scenario: View site list
    Given a site "Blog One" exists
    And a site "Blog Two" exists
    When I go to the sites overview
    Then I should see "Blog One" in the list
    And I should see "Blog Two" in the list

  Scenario: Only see own sites
    Given a site "My Site" exists that belongs to me
    And a site "Other Site" exists that belongs to another user
    When I go to the sites overview
    Then I should see "My Site" in the list
    And I should not see "Other Site" in the list
