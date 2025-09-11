# frozen_string_literal: true

Before do |scenario|
  attach("BASE_IMAGE=#{image_name}", "text/plain")
  if (!ENV['CI'])
    @base_image = Image.new("base-image")
    @base_image.build!("Containerfile")
  end
  base_tag = ENV['CI'] ? image_name('howdy', local: true) : @base_image.tag
  @test_image = Image.new(image_name('howdy-test-runner'), base: base_tag)
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
