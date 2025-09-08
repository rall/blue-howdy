require "aruba/cucumber"

Aruba.configure do |c|
  c.exit_timeout = 30
  c.fixtures_directories << "features/fixtures"
  # Optional: show stdout/stderr when a command fails
  c.activate_announcer_on_command_failure = [:stdout, :stderr]
end

Before do
  setup_aruba
end
