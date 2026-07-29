# frozen_string_literal: true

# Cross-run persistence: window size, sidebar state, theme, and auto-best, in a
# small JSON file under $XDG_CONFIG_HOME/exhibit-rb (a GSettings schema would be
# more GNOME-idiomatic but needs compiling/installing into the Nix store).

require 'json'
require 'fileutils'

module Exhibit
  module AppSettings
    module_function

    DEFAULTS = {
      'width' => 840,
      'height' => 600,
      'sidebar' => true,
      'theme' => 'follow',
      'auto-best' => true,
    }.freeze

    def path
      base = ENV['XDG_CONFIG_HOME'] || File.join(Dir.home, '.config')
      File.join(base, 'exhibit-rb', 'settings.json')
    end

    def get(key) = DEFAULTS.merge(read)[key]

    def update(hash)
      write(read.merge(hash))
    end

    def read
      JSON.parse(File.read(path))
    rescue StandardError
      {}
    end

    def write(data)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(data))
    end
  end
end
