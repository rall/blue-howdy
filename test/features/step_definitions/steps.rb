Given('I am logged in to a fresh blue-howdy image') do
  # Implement the logic to log in to a fresh blue-howdy image
  # This could involve starting a container or setting up a test environment
end

Given(/I run `ujust howdy-pam-add` (to|but don't) add howdy to the (GDM|SDDM) login/) do |act, window_manager|
  # Implement the logic to run the command and configure the login manager
  # Use the `act` and `window_manager` variables to determine the action
end

Given(/I run `ujust howdy-pam-add` (to|but don't) add howdy to sudo/) do |act|
  # Implement the logic to run the command and configure sudo
  # Use the `act` variable to determine the action
end

When('I log out') do
  # Implement the logic to log out of the session
  # This could involve simulating a logout in the test environment
end

When('I log out and back in with my password') do
  # Implement the logic to log out and back in using a password
  # This could involve simulating a logout and login in the test environment
end

Then(/I should (be|not be) able to log in using howdy/) do |act|
  # Implement the logic to verify login capability using howdy
  # Use the `act` variable to determine the expected outcome
end

Then('I should be able to authenticate with sudo using howdy') do
  # Implement the logic to verify sudo authentication using howdy
  # This could involve simulating a sudo command and checking the result
end
