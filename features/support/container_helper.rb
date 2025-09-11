module ContainerHelper
  attr_reader :test_image, :container, :base_image, :image_name

  def image_name(suffix = nil, local: false)
    base = ENV["MATRIX_BASE"]
    stream = ENV["MATRIX_STREAM"]
    suffix_string = suffix ? "-#{suffix}" : ""
    raise "unknown image" unless base && stream
    local_image = "#{base}#{suffix_string}:#{stream}"
    if local
      local_image
    else
      "ghcr.io/ublue-os/#{local_image}"
    end
  end
end

World(ContainerHelper)
