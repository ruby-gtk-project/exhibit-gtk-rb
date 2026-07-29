# frozen_string_literal: true

# Cross-run persistence via GSettings (dconf-backed), like upstream. The schema
# io.github.ruby_gtk_project.Exhibit is compiled into the app by the flake; if
# it isn't installed (e.g. running lib/ from a source checkout without the nix
# build) we degrade to in-memory defaults rather than aborting the process.

require 'gtk4'

module Exhibit
  module AppSettings
    module_function

    SCHEMA = 'io.github.ruby_gtk_project.Exhibit'

    # public key => [gsettings key, type]
    MAP = {
      'width' => ['startup-width', :int],
      'height' => ['startup-height', :int],
      'sidebar' => ['startup-sidebar-show', :boolean],
      'theme' => ['theme', :string],
      'auto-best' => ['auto-best', :boolean],
    }.freeze

    DEFAULTS = {
      'width' => 840,
      'height' => 600,
      'sidebar' => true,
      'theme' => 'follow',
      'auto-best' => true,
    }.freeze

    def get(key)
      gkey, type = MAP[key]
      if settings then settings.__send__(:"get_#{type}", gkey) else DEFAULTS[key] end
    end

    def update(hash)
      hash.each do |key, value|
        gkey, type = MAP[key]
        if settings then settings.__send__(:"set_#{type}", gkey, value) end
      end
    end

    def settings
      unless @resolved
        @resolved = true
        @settings = lookup_settings
      end
      @settings
    end

    def lookup_settings
      source = Gio::SettingsSchemaSource.default
      if source && source.lookup(SCHEMA, true) then Gio::Settings.new(SCHEMA) end
    end
  end
end
