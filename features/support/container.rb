# frozen_string_literal: true
require 'open3'

class Container
  attr_reader :container_id

  def initialize(image_name)
    @image_name = image_name
    @built_image = "#{@image_name}-test"
    @container_id = nil
  end

  def build_image!
    pid = spawn(%Q{#{engine} build --quiet --file features/support/Dockerfile --build-arg BASE_IMAGE=#{@image_name} --tag #{@built_image} .}, out: File::NULL, err: File::NULL)
    Process.wait(pid)
    raise "build failed" unless $?.success?
  end

  def start_container!
    stdout, stderr, status = Open3.capture3(engine.to_s, "run", "-d", @built_image, "tail", "-f", "/dev/null")
    raise "Failed to start container: #{stderr}" unless status.success?
    @container_id = stdout.strip
    raise "Failed to start container (empty id)" if @container_id.empty?
  end

  def run(command)
    stdout, stderr, status = Open3.capture3(engine.to_s, "exec", "-i", @container_id, "bash", "-c", command)
    raise "Command failed: #{stderr}" unless status.success?
    stdout.strip
  end

  def popen(command)
    raise "Container not started" unless @container_id
    Open3.popen2e(engine.to_s, "exec", "-i", @container_id, "bash", "-c", command) do |stdin, io, wait|
      stdin.sync = true
      yield stdin, io if block_given?
      stdin.close
      out = io.read
      raise "Command failed: #{out}" unless wait.value.success?
      out
    end
  end

  def cleanup!
    system(%Q{#{engine} image rm -f #{@built_image}}) rescue warn "Failed to remove #{@built_image}"
  end

  private
  def exec!(cmd)
    system(%Q{#{engine} exec #{@container_id} #{cmd}})
  end

  def engine
    return :podman if system("which podman >/dev/null 2>&1")
    return :docker if system("which docker >/dev/null 2>&1")
    raise "No container engine (need podman or docker)"
  end

  def build_mock!(base_tag:, mock_mode: :success, tag:)
    system(%Q{#{engine} build -f Dockerfile.mock --build-arg BASE_IMAGE=#{base_tag} --build-arg MOCK_MODE=#{mock_mode} -t #{tag} .})
    tag
  end

end
