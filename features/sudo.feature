Feature: Use Howdy to authenticate for sudo

  Background:
    Given I am logged in to a fresh blue-howdy image

    Scenario: Update PAM config for sudo
      When I run 'ujust howdy-pam' to add howdy to sudo
      And I reboot
      Then the PAM config for sudo should contain 'auth sufficient pam_howdy.so'
      And the PAM config for the display manager should not contain 'auth sufficient pam_howdy.so'
      And the PAM config should be syntactically correct

    Scenario: Revert PAM config
      When I run 'ujust howdy-pam' to add howdy to sudo
      And I reboot
      And I run 'ujust howdy-pam' to remove howdy from sudo
      Then the PAM config for sudo should not contain 'auth sufficient pam_howdy.so'
      And the PAM config should be syntactically correct
