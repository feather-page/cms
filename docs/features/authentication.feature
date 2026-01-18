Feature: Authentication
  As a user
  I want to log in and log out
  So that I can manage my websites

  Background:
    Given a user exists with email "test@example.com"

  @javascript
  Scenario: Request login via email
    When I visit the login page
    And I enter my email address "test@example.com"
    And I click "Continue"
    Then I should see a confirmation message
    And a login token should have been generated

  Scenario: Login with valid token
    Given a login token was generated for "test@example.com"
    When I visit the login link from the email
    Then I should be logged in
    And I should be redirected to the sites overview

  Scenario: Login with expired token
    Given an expired login token exists for "test@example.com"
    When I visit the login link from the email
    Then I should be redirected to the login page
    And I should not be logged in

  @javascript
  Scenario: Logout
    Given I am logged in as "test@example.com"
    And I have a site to access
    When I go to the sites overview
    And I click "Logout"
    Then I should be logged out
    And I should be redirected to the login page

  @javascript
  Scenario: Unknown email address
    When I visit the login page
    And I enter my email address "unknown@example.com"
    And I click "Continue"
    Then I should see a confirmation message
