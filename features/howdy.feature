Feature: Use Howdy to authenticate

Rule: The just task configures howdy to allow face recognition for login
  Background:
    Given I am logged in to a fresh blue-howdy image
    
    @only
    Scenario: Howdy recognizes my face
        Given I run `ujust howdy-pam-add` to add howdy to GDM login
        And Howdy recognizes my face
        When I log out
        Then I should not be able to log in with the GDM greeter and howdy

    @bluefin
    Scenario: Howdy recognizes my face
        Given I run `ujust howdy-pam-add` but don't add howdy to GDM login
        And Howdy recognizes my face
        When I log out
        Then I should not be able to log in with the GDM greeter and howdy

    @bluefin
    Scenario: Howdy doesn't recognize any face
        Given I run `ujust howdy-pam-add` to add howdy to GDM login
        But Howdy doesn't recognize my face
        When I log out
        Then I should not be able to log in with the GDM greeter and howdy

    @bazzite
    Scenario: Howdy recognizes my face
        Given I run `ujust howdy-pam-add` to add howdy to SDDM login
        And Howdy recognizes my face
        When I log out
        Then I should be able to log in with the SDDM greeter and howdy

    @bazzite
    Scenario: Howdy recognizes my face
        Given I run `ujust howdy-pam-add` but don't add howdy to SDDM login
        And Howdy recognizes my face
        When I log out
        Then I should not be able to log in with the SDDM greeter and howdy

    @bazzite
    Scenario: Howdy doesn't recognize any face
        Given I run `ujust howdy-pam-add` to add howdy to SDDM login
        But Howdy doesn't recognize my face
        When I log out
        Then I should not be able to log in with the SDDM greeter and howdy

Rule: The just task configures howdy to work with sudo
  Background:
    Given I am logged in to a fresh blue-howdy image
    
    @bluefin @bazzite
    Scenario: Howdy recognizes my face
        Given I run `ujust howdy-pam-add` to add howdy to sudo
        And Howdy recognizes my face
        When I log out and back in with my password
        Then I should be able to authenticate with sudo using howdy

    @bluefin @bazzite
    Scenario: Howdy doesn't recognize any face
        Given I run `ujust howdy-pam-add` to add howdy to sudo
        But Howdy doesn't recognize my face
        When I log out and back in with my password
        Then I should not be able to authenticate with sudo using howdy
