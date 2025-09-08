Feature: Use Howdy to authenticate with my face at login
  Background:
    Given I am logged in to a fresh blue-howdy image
    
    Scenario: Howdy login
        Given Howdy recognizes my face
        When I run `ujust howdy-pam-add` to add howdy to login
        And I log out
        Then I should be able to log in with the OS greeter and howdy

    Scenario: Howdy not configured
        Given Howdy recognizes my face
        When I run `ujust howdy-pam-add` but don't add howdy to login
        And I log out
        Then I should not be able to log in with the OS greeter and howdy

    Scenario: My face isn't recognized
        Given Howdy doesn't recognize my face
        When I run `ujust howdy-pam-add` to add howdy to login
        And I log out
        Then I should not be able to log in with the OS greeter and howdy
