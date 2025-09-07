require_relative "../support/container"

Given('I am logged in to a fresh blue-howdy image') do
  test_image = Image.new("test-image", base: base_image.tag)
  @container = test_image.build!("features/support/Dockerfile")
  container.start!
end

Given(/I run `ujust howdy-pam-add` (to|but don't) add howdy to (login|sudo)/) do |act, pam|
  next if act == "but don't"
  container.popen("stdbuf -oL -eL ujust howdy-pam-add") do |stdin, io|
    io.each_line do |line|
      puts line
      case line
      when /Add Howdy to login/i
        stdin.puts(pam == "login" ? "y" : "n")
      when /Also add Howdy to sudo/i
        stdin.puts(pam == "sudo" ? "y" : "n")
      when /Proceed\?/i
        stdin.puts "y"
      else
        stdin.puts("")
      end
    end
  end
end

Given(/Howdy (recognizes|doesn't recognize) my face/) do |mode|
  mode = (mode == "recognizes") ? "success" : "fail"
  container.run(%Q[bash -c 'echo #{mode} > /etc/howdy/mock_mode'])
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

def pam_dump(svc)
  container.run(%Q{bash -c 'echo "--- /etc/pam.d/#{svc} ---";
                            sed -n "1,120p" /etc/pam.d/#{svc} || true;
                            echo "--- howdy lines ---";
                            grep -n pam_howdy /etc/pam.d/#{svc} || true'})
end

def ensure_pamtester!
  path = container.run(%q{bash -c 'command -v pamtester || true'})
  raise "pamtester not installed in container PATH" if path.strip.empty?
end

Then(/I should (be|not be) able to log in with the OS greeter and howdy/) do |act|
  ensure_pamtester!
  #TODO 
  svc = "gdm-password"

  rc = container.run(%Q{bash -c 'printf "\\n" | pamtester #{svc} testuser authenticate >/dev/null 2>&1; printf "%d" $?; exit 0'})
  if act == "not be"
    raise "expected greeter login to fail (#{svc}), rc=#{rc}\n#{pam_dump(svc)}" if rc == "0"
  else
    raise "expected greeter login to succeed (#{svc}), rc=#{rc}\n#{pam_dump(svc)}" unless rc == "0"
  end
end

Then(/I should (not be|be) able to authenticate with sudo using howdy/) do |act|
  rc = container.run(%q{
    sudo -u testuser sh -c '
      sudo -K
      sudo ls /root >/dev/null 2>&1
      printf "%d" $?; exit 0
    '
  })
  if act == "not be"
    raise "expected sudo authentication via howdy to fail, rc=#{rc}" unless rc != "0"
  else
    raise "expected sudo authentication via howdy to succeed, rc=#{rc}" unless rc == "0"
  end
end
