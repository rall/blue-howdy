Feature: Use Howdy to authenticate

Rule: The just task configures howdy to work with GDM
  Background:
    Given I have just logged in to a fresh blue-howdy image that uses Gnome
    
    @gnome
    Scenario: Howdy is mocked to recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to the GDM login
        When I log out
        Then I should be able to log in using howdy

    @gnome
    Scenario: Howdy is mocked to recognise a face
        Given I run `ujust howdy-pam-add` to not add howdy to the GDM login
        When I log out
        Then I should not be able to log in using howdy

    @gnome
    Scenario: Howdy is mocked to not recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to the GDM login
        When I log out
        Then I should not be able to log in using howdy

Rule: The just task configures howdy to work with sudo
  Background:
    Given I have a fresh blue-howdy image that uses Gnome
    
    @gnome @simple-desktop
    Scenario: Howdy is mocked to recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to sudo
        When I log out and back in with my password
        Then I should be able to authenticate with sudo using howdy

    @gnome @simple-desktop
    Scenario: Howdy is mocked to not recognise a face
        Given I run `ujust howdy-pam-add` to add howdy to sudo
        When I log out and back in with my password
        Then I should be able to authenticate with sudo using howdy
