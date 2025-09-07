require_relative "../support/container"

Given('I am logged in to a fresh blue-howdy image') do
  attach("IMAGE=#{image_name}", "text/plain")
  @container = Container.new(image_name)
  @container.build_image!
  @container.start_container!
end

Given(/I run `ujust howdy-pam-add` (to|but don't) add howdy to (GDM login|SDDM login|sudo)/) do |act, pam|
  next if act == "but don't"
  @container.popen("stdbuf -oL -eL ujust howdy-pam-add") do |stdin, io|
    io.each_line do |line|
      puts line
      case line
      when /Add Howdy to GDM login/i
        stdin.puts(pam == "GDM login" ? "y" : "n")
      when /Add Howdy to SDDM login/i
        stdin.puts(pam == "SDDM login" ? "y" : "n")
      when /Also add Howdy to sudo/i
        stdin.puts(pam == "sudo" ? "y" : "n")
      when /Proceed\?.*\[y\/N\]/i
        stdin.puts "y"
      else
        stdin.puts("")
      end
    end
  end
end

Given(/Howdy (recognizes|doesn't recognize) my face/) do |mode|
  mode = (mode == "recognizes") ? "success" : "fail"
  @container.run(%Q[bash -lc 'echo #{mode} > /etc/howdy/mock_mode'])
end

When('I log out') do
  @container.run(%q{sudo -u testuser sh -c 'sudo -K'})
end

When('I log out and back in with my password') do
  @container.run(%q{
    sudo -u testuser sh -c '
      sudo -K
      printf "#!/bin/sh\necho testuser\n" > /tmp/ask.sh
      chmod 700 /tmp/ask.sh
      SUDO_ASKPASS=/tmp/ask.sh sudo -A -v
      sudo -n true
    '
  })
end

Then(/I should (be|not be) able to log in with the (GDM|SDDM) greeter and howdy/) do |act, manager|
  pam = manager == "SDDM" ? "sddm" : "gdm-password"
  rc = @container.run(%Q{bash -c 'printf "\\n" | pamtester #{pam} testuser authenticate >/dev/null 2>&1; printf "%d" $?; exit 0'})
  if act == "not be"
    raise "expected greeter login via howdy to fail (service=#{pam}), rc=#{rc}" unless rc != "0"
  else
    raise "expected greeter login via howdy to succeed (service=#{pam}), rc=#{rc}" unless rc == "0"
  end
end

Then(/I should (not be|be) able to authenticate with sudo using howdy/) do |act|
  @container.run(%q{sudo -K})  # Clear the sudo cache

  rc = @container.run(%q{
    sudo -u testuser sh -c '
      printf "#!/bin/sh\necho testuser\n" > /tmp/ask.sh
      chmod 700 /tmp/ask.sh
      SUDO_ASKPASS=/tmp/ask.sh sudo -A -v
      sudo -n true
    '
  })

  if act == "not be"
    raise "expected sudo authentication via howdy to fail, rc=#{rc}" unless rc != "0"
  else
    raise "expected sudo authentication via howdy to succeed, rc=#{rc}" unless rc == "0"
  end
end
