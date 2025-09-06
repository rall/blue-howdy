# frozen_string_literal: true

def image_name()
  base   = ENV["MATRIX_BASE"]
  stream = ENV["MATRIX_STREAM"]
  if base && stream
    "ghcr.io/rall/#{base}-howdy:#{stream}" 
  else
    raise "unknown image"
  end
end

BeforeAll do 
end

Before do |scenario|
  scenario.attach("IMAGE=#{image_name}", "text/plain")
end

AfterAll do
  # stop container, remove image
end
