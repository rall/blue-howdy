# frozen_string_literal: true

def build_image_name(base, stream)
  if base && stream
    "ghcr.io/rall/#{base}-howdy:#{stream}" 
  else
    raise "unknown image"
  end
end

BeforeAll do 
  base   = ENV["MATRIX_BASE"]
  stream = ENV["MATRIX_STREAM"]
  @image = ENV["IMAGE"] || build_image_name(base, stream)
  attach("IMAGE=#{@image}", "text/plain")
end

Before do |scenario|
  unless scenario.source_tag_names.any? { |tag| @image.include?(tag.slice(0)) }
    skip_this_scenario
  end
end

AfterAll do
  # stop container, remove image
end
