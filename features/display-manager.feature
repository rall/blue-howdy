Feature: Use Howdy to authenticate with my face at login

  Background:
    Given I am logged in to a fresh blue-howdy image

    Scenario: Update PAM config for display manager login
      When I run 'ujust howdy-pam' to add howdy to login
      And I reboot
      Then the PAM config for the display manager should contain 'auth sufficient pam_howdy.so'
      And the PAM config for sudo should not contain 'auth sufficient pam_howdy.so'
      And the PAM config should be syntactically correct

    Scenario: Revert PAM config
      When I run 'ujust howdy-pam' to add howdy to login
      And I reboot
      And I run 'ujust howdy-pam' to remove howdy from login
      Then the PAM config for the display manager should not contain 'auth sufficient pam_howdy.so'
      And the PAM config should be syntactically correct
