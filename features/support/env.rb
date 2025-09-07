# frozen_string_literal: true

BeforeAll do
end

Before do |scenario|
  attach("BASE_IMAGE=#{ENV['MATRIX_BASE']}", "text/plain")
  attach("STEREAM=#{ENV['MATRIX_STREAM']}", "text/plain")
  puts image_name
  unless base_image
    @base_image = Image.new("test_image", base: image_name)
    base_image.build!("Containerfile")
  end
end

AfterAll do
  # stop container, remove image
end

After do |scenario|
  if @container
    @container.cleanup!
  end
end
