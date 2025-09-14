require "aruba/cucumber"
require_relative "../support/container"

Given('I am logged in to a fresh blue-howdy image') do
  container.start!
end

When(/I run 'ujust howdy-pam' to (add howdy to|remove howdy from) (login|sudo)/) do |act, pam|
  answers = {
    :"Add Howdy to login?" => (pam == "login" && act == "add howdy to"),
    :"Remove Howdy from login?" => (pam == "login" && act == "remove howdy from"),
    :"Add Howdy to sudo?" => (pam == "sudo" && act == "add howdy to"),
    :"Remove Howdy from sudo?" => (pam == "sudo" && act == "remove howdy from"), 
  }
  run_command(container.exec_cmd("ujust howdy-pam", interactive: true, root: true))
  last_line = ""
  until last_line.include?("Done. Now lock your session or switch user to test the greeter.")
    answers.each do |k, v|
      if last_line.include?(k.to_s)
        last_command_started.write v ? "y" : "n"
      end
    end
    sleep 0.5
    lines = last_command_started.output.split("\n")
    last_line = lines.select { |line| !line.start_with?("Unable to create log dir")  }.last
    puts last_line
  end
  last_command_started.write "exit"
  last_command_started.stop
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

When('I reboot') do ||
  container.restart!
end

