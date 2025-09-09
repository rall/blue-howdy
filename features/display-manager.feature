Feature: Use Howdy to authenticate with my face at login

  Background:
    Given I am logged in to a fresh blue-howdy image

  Rule: PAM Config must be syntactically correct

    Scenario: After system boots
      When I run 'ujust howdy-pam-add' to add howdy to login
      Then the PAM config should be syntactically correct

  Rule: PAM config must start with howdy line

    Scenario: After system boots
      When I run 'ujust howdy-pam-add' to add howdy to login
      Then the PAM config for the display manager should contain 'auth sufficient pam_howdy.so'

  Rule: Howdy must be installed

    Scenario: After system boots
      When I run 'ujust howdy-pam-add' to add howdy to login
      Then howdy must be installed

  Rule: SELinux module store must be repairable

    Scenario: After system boots
      When I run 'ujust howdy-pam-add' to add howdy to login
      Then I can run 'ujust howdy-selinux-repair-start'
      And I can run 'ujust howdy-selinux-repair-finish'
