# frozen_string_literal: true

require_relative "matrix"

VARIANT = begin
  img = ENV["BASE_IMAGE"] || ENV["IMAGE_NAME"] || ENV["VARIANT"]
  if img
    base = img.split("/").last.split(":").first.sub(/-howdy$/, "")
    { base: base.to_sym }
  end
end

Before do |scenario|
  if scenario.source_tag_names.include?("@gnome") &&
     !(VARIANT && has?(VARIANT, :gdm))
    skip_this_scenario("Skipping @gnome scenario for image without GNOME")
  end
end

After do
  if @mock_tag
    Container.cleanup!(@mock_tag)
  end
end

