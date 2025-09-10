# frozen_string_literal: true

Before do |scenario|
  attach("BASE_IMAGE=#{image_name}", "text/plain")
  @base_image = Image.new("base-image", base: image_name)
  base_image.build!("Containerfile")
  @test_image = Image.new("test-image", base: base_image.tag)
  @container = test_image.build!("features/support/Dockerfile")
  @container.env.each do |k, v|
    prepend_environment_variable(k, v)
  end
end

After do |scenario|
  @container.cleanup!
  test_image.cleanup!
  base_image.cleanup!
end 
