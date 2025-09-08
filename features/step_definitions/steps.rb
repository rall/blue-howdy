require "aruba/cucumber"
require_relative "../support/container"

Given('I am logged in to a fresh blue-howdy image') do
  test_image = Image.new("test-image", base: base_image.tag)
  @container = test_image.build!("features/support/Dockerfile")
  container.start!
end

Given(/I run `ujust howdy-pam-add` (to|but don't) add howdy to (login|sudo)/) do |act, pam|
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
        puts("answering #{k} with #{v}")
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

Given('I start SELinux repair') do
  container.run(%q{bash -c 'ujust howdy-selinux-repair-start'})
end

Given('I finish SELinux repair') do
  container.run(%q{bash -c 'ujust howdy-selinux-repair-finish'})
end

When('I log out') do
  container.run(%q{sudo -u testuser sh -c 'sudo -K'})
end

When('I log out and back in with my password') do
  container.run(%q{
    sudo -u testuser sh -c '
      sudo -K
      printf "#!/bin/sh\necho testuser\n" > /tmp/ask.sh
      chmod 700 /tmp/ask.sh
      SUDO_ASKPASS=/tmp/ask.sh sudo -A -v
      sudo -n true
    '
  })
end

Then(/I should (be|not be) able to log in with the OS greeter and howdy/) do |act|
  #TODO 
  svc = "gdm-password"

  run_command_and_stop(container.exec_cmd("howdy test"), fail_on_error: false, exit_timeout: 0.2)
  puts last_command_started.exit_status

  run_command_and_stop(container.exec_cmd("pamtester -v #{svc} testuser authenticate"), fail_on_error: false, exit_timeout: 0.2)
  pamtester_exit_code = last_command_started.exit_status
  puts last_command_started.output
  puts pamtester_exit_code
  if act == "not be"
    raise "expected #{svc} login to fail" if pamtester_exit_code == 0
  else
    raise "expected #{scv} login to succeed" unless pamtester_exit_code == 0
  end
end

Then(/I should (not be|be) able to authenticate with sudo using howdy/) do |act|
  run_command_and_stop(container.exec_cmd("howdy test"), fail_on_error: false, exit_timeout: 0.2)
  puts last_command_started.exit_status

  run_command_and_stop(container.exec_cmd("sudo -u testuser sudo -K"))
  run_command_and_stop(
    container.exec_cmd(%q{
      sudo -u testuser sh -c '
        printf "#!/bin/sh\necho x\n" > /tmp/ask.sh && chmod 700 /tmp/ask.sh
        SUDO_ASKPASS=/tmp/ask.sh sudo -A -v
      '
    }),
    fail_on_error: false, exit_timeout: 6
  )
  run_command_and_stop(container.exec_cmd("sudo -u testuser sudo -n true"), fail_on_error: false, exit_timeout: 0.2)
  puts last_command_started.output
  sudo_exit_code = last_command_started.exit_status
  if act == "not be"
    raise "expected sudo authentication via howdy to fail" if sudo_exit_code == 0
  else
    raise "expected sudo authentication via howdy to succeed" unless sudo_exit_code == 0
  end
end
