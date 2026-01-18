Feature: Unsplash Image Search
  As a content editor
  I want to search for images on Unsplash
  So that I can use high-quality stock photos in my content

  Background:
    Given I am logged in
    And I have a site "My Blog"

  Scenario: Search for images on Unsplash
    Given the Unsplash API is available
    When I search for "nature" on Unsplash
    Then I should see Unsplash search results
    And each result should have a thumbnail and photographer info

  Scenario: Search returns no results for short queries
    When I search for "a" on Unsplash
    Then I should see no Unsplash results

  Scenario: Add an image from Unsplash
    Given the Unsplash API is available
    And an Unsplash photo "abc123" exists
    When I add the Unsplash photo "abc123" to my site
    Then the image should be saved to my site
    And the image should have Unsplash attribution data
