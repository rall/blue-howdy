module ContainerHelper
  attr_reader :test_image, :container, :base_image, :image_name

  def image_name(suffix = nil)
    base = ENV["MATRIX_BASE"]
    stream = ENV["MATRIX_STREAM"]
    suffix_string = suffix ? "-#{suffix}" : ""
    if base && stream
      "ghcr.io/ublue-os/#{base}#{suffix_string}:#{stream}"
    else
      raise "unknown image"
    end
  end
end

World(ContainerHelper)
