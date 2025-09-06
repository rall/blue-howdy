# frozen_string_literal: true
require "yaml"

wf = YAML.load_file(File.expand_path("../../.github/workflows/build.yml", __dir__))
matrix = wf.dig("jobs", "build_push", "strategy", "matrix")
bases = matrix.fetch("base")
streams = matrix.fetch("stream")

VARIANTS = bases.product(streams).map do |base, stream|
  {
    base: base.to_sym,
    stream: stream.to_sym,
    base_tag: "ghcr.io/ublue-os/#{base}:#{stream}",
    name: "#{base}-howdy",
    tag: "ghcr.io/rall/#{base}-howdy:#{stream}"
  }
end

DISPLAY_MANAGERS = {
  :bluefin => %i[gdm],
  :"bluefin-dx" => %i[gdm],
  :"bluefin-nvidia" => %i[gdm],
  :"bluefin-dx-nvidia-open" => %i[gdm],
  :"bazzite-kde" => %i[sddm]
}

def has?(variant, dm)
  base = variant.fetch(:base)
  DISPLAY_MANAGERS.fetch(base, []).include?(dm.to_sym)
end
