module ContainerHelper
  attr_reader :test_image, :container, :base_image, :image_name

  def image_name(suffix = nil, local: false)
    base = ENV["MATRIX_BASE"]
    stream = ENV["MATRIX_STREAM"]
    suffix_string = suffix ? "-#{suffix}" : ""
    if base && stream
      local_image = "#{base}#{suffix_string}:#{stream}"
    else
      raise "unknown image"
    end
    if local
      "localhost/#{local_image}"
    else
      "ghcr.io/ublue-os/#{local_image}"
    end
  end
end

World(ContainerHelper)
