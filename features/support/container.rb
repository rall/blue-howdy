# frozen_string_literal: true
require "open3"
require 'securerandom'

class Runtime
  def cleanup!
    raise "Not implemented"
  end

  def engine
    return "docker" if system("command -v docker >/dev/null 2>&1")
    return "podman" if system("command -v podman >/dev/null 2>&1")
    raise "No container engine (need podman or docker)"
  end

  def podman?
    engine == "podman"
  end

  def docker?
    engine == "docker"
  end

  def ci?
    ENV["CI"]
  end

  def env
    if podman? 
      @env ||= {
        "XDG_DATA_HOME"   => ENV["XDG_DATA_HOME"]   || "/tmp/blue-howdy/podman-data",
        "XDG_CONFIG_HOME" => ENV["XDG_CONFIG_HOME"] || "/tmp/blue-howdy/podman-config",
      }.tap do |podman_env|
        [podman_env["XDG_DATA_HOME"], podman_env["XDG_CONFIG_HOME"]].each { |d| FileUtils.mkdir_p(d) }
      end
    else
      @env ||= Hash.new
    end
    @env
  end
end

class Image < Runtime
  attr_reader :tag

  # Initialize with the base image string to pass to the overlay build,
  # or nil if the Dockerfile doesn't require BASE_IMAGE.
  def initialize(name, base: nil)
    @tag = "#{name}-#{SecureRandom.uuid}"
    @base = base
  end

  # Build exactly the Dockerfile given. If @base is set, pass it as BASE_IMAGE.
  # Tags the result with a unique, local name and returns a Container bound to it.
  def build!(dockerfile)
    opts = ["--tag=#{@tag}"]
    opts << "--file=#{dockerfile}" if docker?
    opts << "--build-arg=BASE_IMAGE=#{@base}" if @base
    opts << "." if docker?
    opts << File.dirname(File.absolute_path(dockerfile)) if podman?
    output, status = Open3.capture2e(env, engine, "build", *opts)
    raise "Build failed: #{output}" unless status.success?
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
    run_args =  ["run", "--detach", "--entrypoint", "tail", @image.tag, "tail", "-f", "/dev/null"]
    stdout, stderr, status = Open3.capture3(env, engine, *run_args)
    raise "Failed to start container: #{stderr}" unless status.success?
    @id = stdout.strip
    raise "Failed to start container (empty id)" if @id.empty?
  end

  def exec_cmd(cmd, interactive: false, debug: false)
    raise "Container not started" unless @id
    flags = []
    flags << "-i" if interactive
    flags << "-t" if interactive && podman? && !ci?
    localenv = 'env -i TERM=xterm-256color'
    command = interactive || ci? ? "bash -c \"script -qef -c '#{cmd}' /dev/null\"" : "bash -lc '#{cmd}'"
    debug_engine = debug ? "#{engine} --log-level=debug" : engine
    "#{debug_engine} exec #{flags.join(' ')} #{@id} #{localenv} #{command}".squeeze(' ').tap do |full|
      STDERR.puts("EXEC: #{full}") if debug
    end
  end

  def cleanup!
    return if podman?
    system(engine, "stop", @id)
    system(engine, "rm", @id) 
  end
end
