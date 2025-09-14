Feature: Use Howdy to authenticate for sudo

  Background:
    Given I am logged in to a fresh blue-howdy image

    Scenario: PAM Config must be syntactically correct
      When I run 'ujust howdy-pam' to add howdy to sudo
      And I reboot
      Then the PAM config should be syntactically correct

    Scenario: PAM config must start with howdy line
      When I run 'ujust howdy-pam' to add howdy to sudo
      And I reboot
      Then the PAM config for sudo should contain 'auth sufficient pam_howdy.so'
      And the PAM config for the display manager should not contain 'auth sufficient pam_howdy.so'
