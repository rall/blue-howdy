# frozen_string_literal: true

Before do |scenario|
  attach("BASE_IMAGE=#{image_name}", "text/plain")
  if (ENV['CI'])
    @base_image = Image.prebuilt(image_name("howdy", local: true))
  else 
    @base_image = Image.new("base-image")
    @base_image.build!("Containerfile")
  end
  @test_image = Image.new(image_name('howdy'), base: @base_image.tag)
  @container = test_image.build!("features/support/Dockerfile")
  @container.env.each do |k, v|
    prepend_environment_variable(k, v)
  end
end

After do |scenario|
  @container.cleanup!
  test_image.cleanup!
  @base_image.cleanup!
end 
