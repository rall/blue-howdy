module ContainerHelper
  attr_reader :test_image, :container, :base_image, :image_name

  def image_name()
    base = ENV["MATRIX_BASE"]
    stream = ENV["MATRIX_STREAM"]
    if base && stream
      "ghcr.io/ublue-os/#{base}:#{stream}" 
    else
      raise "unknown image"
    end
  end
end

World(ContainerHelper)
