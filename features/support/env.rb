# frozen_string_literal: true

Before do
  attach("BASE_IMAGE=#{image_name}", "text/plain")
  test_image_name = image_name('howdy', local: true)
  runner_image_name = image_name('howdy-runner', local: true)
  if (!ENV['CI'])
    @base_image = Image.new(test_image_name)
    @base_image.build!("Containerfile", base: image_name, pull: true)
  end
  @test_image = Image.new(runner_image_name)
  @container = test_image.build!("features/support/Dockerfile", base: test_image_name)
  @container.env.each do |k, v|
    prepend_environment_variable(k, v)
  end
end

After do
  @container.cleanup!
  test_image.cleanup!
  @base_image.cleanup! if @base_image
end 
