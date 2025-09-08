require "aruba/cucumber"
require_relative "../support/container"

Given('I am logged in to a fresh blue-howdy image') do
  test_image = Image.new("test-image", base: base_image.tag)
  @container = test_image.build!("features/support/Dockerfile")
  container.start!
end

When(/I run `ujust howdy-pam-add` (to|but don't) add howdy to (login|sudo)/) do |act, pam|
  next if act == "but don't"

  answers = {
    proceed: "y",
    login: (pam == "login" ? "y" : "n"),
    sudo: (pam == "sudo"  ? "y" : "n")
  }

  run_command(container.exec_cmd("LC_ALL=C ujust howdy-pam-add"))
  until last_command_started.output.include?("Done. Now lock your session or switch user to test the greeter.")
    answers.each do |k, v|
      if last_command_started.output.include?(k.to_s)
        last_command_started.write v
        sleep 0.5
      end
    end
  end
  last_command_started.stop
end

Given(/Howdy (recognizes|doesn't recognize) my face/) do |mode|
  mode = (mode == "recognizes") ? "success" : "fail"
  container.run(%Q[bash -c 'echo #{mode} > /run/mock-howdy-mode'])
end

When('I log out') do
  container.run(%q{sudo -u testuser sh -c 'sudo -K'})
end

Then(/I should (be|not be) able to log in with the OS greeter and howdy/) do |act|
  #TODO 
  svc = "gdm-password"

  run_command(container.exec_cmd("pamtester #{svc} testuser authenticate"), fail_on_error: false, exit_timeout: 0.2)
  last_command_started.write "bad-password\n"
  last_command_started.stop
  if act == "not be"
    raise "expected #{svc} login to fail" if last_command_started.exit_status == 0
  else
    raise "expected #{svc} login to succeed" unless last_command_started.exit_status == 0
  end
end

Then(/I should (not be|be) able to authenticate with sudo using howdy/) do |act|
  run_command(container.exec_cmd("pamtester sudo testuser authenticate"), fail_on_error: false, exit_timeout: 0.2)
  last_command_started.write "bad-password\n"
  last_command_started.stop
  if act == "not be"
    raise "expected sudo authentication via howdy to fail" if last_command_started.exit_status == 0
  else
    raise "expected sudo authentication via howdy to succeed" unless last_command_started.exit_status == 0
  end
end
