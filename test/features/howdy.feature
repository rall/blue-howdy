Feature: Use Howdy to authenticate

Rule: The just task configures howdy to allow face recognition for login
  Background:
    Given I am logged in to a fresh blue-howdy image
    
    @bluefin
    Scenario: Howdy is mocked to recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to the GDM login
        When I log out
        Then I should be able to log in using howdy

    @bluefin
    Scenario: Howdy is mocked to recognise a face
        Given I run `ujust howdy-pam-add` but don't add howdy to the GDM login
        When I log out
        Then I should not be able to log in using howdy

    @bluefin
    Scenario: Howdy is mocked to not recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to the GDM login
        When I log out
        Then I should not be able to log in using howdy

    @bazzite
    Scenario: Howdy is mocked to recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to the SDDM login
        When I log out
        Then I should be able to log in using howdy

    @bazzite
    Scenario: Howdy is mocked to recognise a face
        Given I run `ujust howdy-pam-add` but don't add howdy to the SDDM login
        When I log out
        Then I should not be able to log in using howdy

    @bazzite
    Scenario: Howdy is mocked to not recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to the SDDM login
        When I log out
        Then I should not be able to log in using howdy

Rule: The just task configures howdy to work with sudo
  Background:
    Given I am logged in to a fresh blue-howdy image
    
    @bluefin @bazzite
    Scenario: Howdy is mocked to recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to sudo
        When I log out and back in with my password
        Then I should be able to authenticate with sudo using howdy

    @bluefin @bazzite
    Scenario: Howdy is mocked to not recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to sudo
        When I log out and back in with my password
        Then I should be able to authenticate with sudo using howdy
