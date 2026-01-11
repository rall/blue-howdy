require "aruba/cucumber"
require_relative "../support/container"

Given('I am logged in to a fresh blue-howdy image') do
  container.start!
  run_command_and_stop(container.exec_cmd("cat /etc/fedora-release"))
  puts image_name
  puts last_command_started.output
end

When("I run 'ujust howdy-enable'") do
  run_command_and_stop(container.exec_cmd("ujust howdy-enable", root: true), fail_on_error: true)
end

When("I run 'ujust howdy-disable'") do
  run_command_and_stop(container.exec_cmd("ujust howdy-disable", root: true), fail_on_error: true)
end

Then('the PAM config should be syntactically correct') do
  run_command_and_stop(container.exec_cmd("authselect check"), fail_on_error: true)
end

Then(/the PAM config for (the display manager|sudo) (should not|should) contain '([^']+)'/) do |service_test, shd, pam_line|
  should = {
    "should" => true,
    "should not" => false
  }[shd]
  if service_test == "sudo"
    service = service_test
  else
    run_command_and_stop(container.exec_cmd("ls /etc/pam.d"), fail_on_error: false)
    ["gdm-password", "sddm"].each do |pam|
      if last_command_started.output.include?(pam)
        service = pam
      end
    end
  end
  raise "Unknown service" unless service
  run_command_and_stop(container.exec_cmd("cat /etc/pam.d/#{service}"), fail_on_error: false)
  if should
    raise "#{pam_line} not present in /etc/pam.d/#{service}" unless last_command_started.output.include?(pam_line)
  else
    raise "#{pam_line} present in /etc/pam.d/#{service}" if last_command_started.output.include?(pam_line)
  end
end

Then('howdy must be installed') do
  run_command_and_stop(container.exec_cmd("howdy -h"), fail_on_error: true)
end

When('I reboot') do
  container.restart!
  run_command_and_stop(container.exec_cmd("/usr/libexec/howdy-selinux-setup", root: true), fail_on_error: true)
end
