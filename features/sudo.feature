Feature: Use Howdy to authenticate for sudo

  Background:
    Given I am logged in to a fresh blue-howdy image

    Scenario: PAM Config must be syntactically correct
      When I run 'ujust howdy-pam-add' to add howdy to sudo
      Then the PAM config should be syntactically correct

    Scenario: PAM config must start with howdy line
      When I run 'ujust howdy-pam-add' to add howdy to sudo
      Then the PAM config for sudo should contain 'auth sufficient pam_howdy.so'

    Scenario: Howdy must be installed
      When I run 'ujust howdy-pam-add' to add howdy to sudo
      Then howdy must be installed

    Scenario: SELinux module store must be repairable
      When I run 'ujust howdy-pam-add' to add howdy to sudo
      Then I can run 'ujust howdy-selinux-repair-start'
      And I can run 'ujust howdy-selinux-repair-finish'
