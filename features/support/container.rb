# frozen_string_literal: true
require "open3"

class Runtime
  def cleanup!
    raise "Not implemented"
  end

  protected

  def engine
    return "podman" if system("command -v podman >/dev/null 2>&1")
    return "docker" if system("command -v docker >/dev/null 2>&1")
    raise "No container engine (need podman or docker)"
  end
end

class Image < Runtime
  attr_reader :tag

  # Initialize with the base image string to pass to the overlay build,
  # or nil if the Dockerfile doesn't require BASE_IMAGE.
  def initialize(tag, base: nil)
    @base = base
    @tag  = tag
  end

  # Build exactly the Dockerfile given. If @base is set, pass it as BASE_IMAGE.
  # Tags the result with a unique, local name and returns a Container bound to it.
  def build!(dockerfile)
    args = ["--file", dockerfile, "--build-arg", "BASE_IMAGE=#{@base}", "--tag", @tag]
    pid = spawn(engine, "build", *args, ".", out: File::NULL, err: File::NULL)
    Process.wait(pid)
    raise "build failed (#{dockerfile})" unless $?.success?
    Container.new(self)
  end

  def cleanup!
    system(engine, "image", "rm", "-f", @tag)
  end
end

class Container < Runtime
  attr_reader :id

  def initialize(image)
    @image = image
    @id    = nil
  end

  # Start a long-lived container from the image's tag.
  def start!
    stdout, stderr, status =
      Open3.capture3(engine, "run", "-d",
                     "--entrypoint", "tail", @image.tag,
                     "-f", "/dev/null")
    raise "Failed to start container: #{stderr}" unless status.success?
    @id = stdout.strip
    raise "Failed to start container (empty id)" if @id.empty?
  end

  def run(cmd)
    stdout, stderr, status =
      Open3.capture3(engine, "exec", "-i", @id, "bash", "-c", cmd)
    raise "Command failed: #{stderr}" unless status.success?
    stdout.strip
  end

  def popen(cmd)
    raise "Container not started" unless @id
    Open3.popen2e(engine, "exec", "-i", @id, "bash", "-c", cmd) do |stdin, io, wait|
      stdin.sync = true
      yield stdin, io if block_given?
      stdin.close
      out = io.read
      raise "Command failed: #{out}" unless wait.value.success?
      out
    end
  end

  def exec_cmd(*args)
    raise "Container not started" unless @id
    %(#{engine} exec -i #{@id} bash -c 'LC_ALL=C script -q -e -c "#{args.join(" ")}" /dev/null')
  end

  def cleanup!
    system(engine, "stop", @id)
    system(engine, "rm", "-f", @id)
    @image.cleanup!
  end
end
