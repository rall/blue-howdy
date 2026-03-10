Feature: Use Howdy to authenticate with my face for sudo/polkit

  Background:
    Given I am logged in to a fresh blue-howdy image

    Scenario: Enable Howdy authentication
      When I run 'ujust howdy-enable'
      And I reboot
      Then the PAM config for sudo should contain 'pam_howdy.so'
      And the PAM config for the display manager should not contain 'pam_howdy.so'
      And the PAM config should be syntactically correct

    Scenario: Disable Howdy authentication
      When I run 'ujust howdy-enable'
      And I reboot
      And I run 'ujust howdy-disable'
      Then the PAM config for sudo should not contain 'pam_howdy.so'
      And the PAM config for the display manager should not contain 'pam_howdy.so'
      And the PAM config should be syntactically correct
