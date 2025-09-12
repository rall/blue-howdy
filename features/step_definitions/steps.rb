require "aruba/cucumber"
require_relative "../support/container"

Given('I am logged in to a fresh blue-howdy image') do
  container.start!
end

When(/I run 'ujust howdy-pam-add' (to|but don't) add howdy to (login|sudo)/) do |act, pam|
  next if act == "but don't"
  answers = {
    :"Add Howdy to login" => (pam == "login" ? "y" : "n"),
    :"Add Howdy to sudo" => (pam == "sudo"  ? "y" : "n"),
    :"Proceed?" => "y",
  }
  run_command(container.exec_cmd("ujust howdy-pam-add", interactive: true, root: true))
  until last_command_started.output.include?("Done. Now lock your session or switch user to test the greeter.")
    answers.each do |k, v|
      if last_command_started.output.include?(k.to_s)
        last_command_started.write v
      end
    end
    sleep 0.5
  end
  last_command_started.stop
end


Then('the PAM config should be syntactically correct') do 
  run_command_and_stop(container.exec_cmd("authselect check"), fail_on_error: true)
end

Then(/the PAM config for (the display manager|sudo) should contain '([^']+)'/) do |service_test, pam_line|
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
  raise "#{pam_line} not present in /etc/pam.d/#{service}" unless last_command_started.output.include?(pam_line)
end

Then(/I can run 'ujust (.*)'/) do |just_task|
  run_command(container.exec_cmd("ujust #{just_task}", interactive: true), fail_on_error: true, exit_timeout: 10)
end

Then('howdy must be installed') do
  run_command_and_stop(container.exec_cmd("howdy -h"), fail_on_error: true)
end

When('I reboot') do ||
  container.restart!
end
