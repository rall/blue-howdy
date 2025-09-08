Feature: Use Howdy to authenticate

Rule: The just task configures howdy to allow face recognition for login
  Background:
    Given I am logged in to a fresh blue-howdy image
    
    Scenario: Howdy login
        Given I run `ujust howdy-pam-add` to add howdy to login
        And Howdy recognizes my face
        When I log out
        Then I should be able to log in with the OS greeter and howdy

    Scenario: Howdy not configured
        Given I run `ujust howdy-pam-add` but don't add howdy to login
        And Howdy recognizes my face
        When I log out
        Then I should not be able to log in with the OS greeter and howdy

    Scenario: My face isn't recognized
        Given I run `ujust howdy-pam-add` to add howdy to login
        But Howdy doesn't recognize my face
        When I log out
        Then I should not be able to log in with the OS greeter and howdy

Rule: The just task configures howdy to work with sudo
  Background:
    Given I am logged in to a fresh blue-howdy image
    
    Scenario: Use sudo when Howdy recognizes my face
        Given I run `ujust howdy-pam-add` to add howdy to sudo
        And Howdy recognizes my face
        When I log out and back in with my password
        Then I should be able to authenticate with sudo using howdy

    Scenario: Use sudo when Howdy doesn't recognize any face
        Given I run `ujust howdy-pam-add` to add howdy to sudo
        But Howdy doesn't recognize my face
        When I log out and back in with my password
        Then I should not be able to authenticate with sudo using howdy
