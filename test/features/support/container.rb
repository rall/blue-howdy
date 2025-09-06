# frozen_string_literal: true

class Container
  attr_reader :container_id

  def initialize(image_name)
    @image_name = image_name
    @container_id = nil
  end

  def start_container!
    e = engine or raise "No container engine (need podman or docker)"
    require 'open3'
    stdout, stderr, status = Open3.capture3("#{e} run -d #{@image_name}")
    raise "Failed to start container: #{stderr}" unless status.success?
    @container_id = stdout.strip
    raise "Failed to start container" if @container_id.empty?
  end

  private
  def exec!(cmd)
    e = engine or raise "No container engine (need podman or docker)"
    sh!(%Q{#{e} exec #{@container_id} #{cmd}})
  end
  
  def engine
    return :podman if system("which podman >/dev/null 2>&1")
    return :docker if system("which docker >/dev/null 2>&1")
    nil
  end

  def sh!(cmd)
    ok = system(cmd)
    ok or raise "Command failed: #{cmd}"
  end

  def build_mock!(base_tag:, mock_mode: :success, tag:)
    e = engine or raise "No container engine (need podman or docker)"
    sh!(%Q{#{e} build -f Dockerfile.mock --build-arg BASE_IMAGE=#{base_tag} --build-arg MOCK_MODE=#{mock_mode} -t #{tag} .})
    tag
  end

  # cleanup helper: delete images we built for tests
  def cleanup!(tags)
    e = engine or return
    Array(tags).each do |tag|
      sh!(%Q{#{e} image rm -f #{tag}}) rescue warn "Failed to remove #{tag}"
    end
  end
end
