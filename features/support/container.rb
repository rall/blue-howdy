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

  def podman?
    engine == "podman"
  end

  def docker?
    engine == "docker"
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
    run_args = ["run", "-d"]
    # keep host uid/gid mapping only for podman (docker doesn’t know this flag)
    run_args += ["--userns=keep-id"] if podman?
    run_args += ["--entrypoint", "tail", @image.tag, "-f", "/dev/null"]
    stdout, stderr, status = Open3.capture3(engine, *run_args)
    raise "Failed to start container: #{stderr}" unless status.success?
    @id = stdout.strip
    raise "Failed to start container (empty id)" if @id.empty?
  end

  def exec_cmd(cmd, interactive: false, debug: false)
    raise "Container not started" unless @id
    flags = []
    flags << "-i" if interactive
    flags << "-t" if interactive && podman?
    env = 'env -i PATH=/usr/sbin:/usr/bin:/usr/local/bin:/sbin:/bin LC_ALL=C TERM=xterm-256color'
    command = interactive ? "bash -c \"script -qef -c '#{cmd}' /dev/null\"" : "bash -lc '#{cmd}'"
    debug_engine = debug ? "#{engine} --log-level=debug" : engine
    "#{debug_engine} exec #{flags.join(' ')} #{@id} #{env} #{command}".squeeze(' ').tap do |full|
      STDERR.puts("EXEC: #{full}") if debug
    end
  end

  def cleanup!
    system(engine, "stop", @id)
    system(engine, "rm", "-f", @id)
    @image.cleanup!
  end
end
