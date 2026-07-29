# frozen_string_literal: true

# Loads the render presets ("configurations"): the bundled defaults
# (data/configurations.json) plus any user presets under
# $XDG_DATA_HOME/exhibit-rb/configurations. Each entry is:
#   { "name", "formats" (a regex), "view-settings" {}, "other-settings" {} }
# match() picks the preset whose formats regex matches a filepath (for
# auto-best); save() writes a new user preset.

require 'json'
require 'fileutils'

module Exhibit
  class ConfigurationStore
    REQUIRED_KEYS = %w[name formats view-settings other-settings].freeze

    def initialize
      @configs = {}
      load_bundled
      load_user
    end

    def keys = @configs.keys
    def [](key) = @configs[key]
    def name_of(key) = @configs.dig(key, 'name')

    # The preset whose formats regex matches the path; falls back to 'general'.
    def match(filepath)
      key = @configs.find do |_k, cfg|
        cfg['formats'] != '.*()' && Regexp.new(cfg['formats']).match?(filepath)
      end
      key ? key.first : 'general'
    end

    def save(name, formats, view_settings, other_settings)
      key = name.downcase.tr(' ', '_')
      config = {
        'name' => name,
        'formats' => ".*(#{formats.split(',').map(&:strip).join('|')})",
        'view-settings' => view_settings,
        'other-settings' => other_settings,
      }
      @configs[key] = config
      FileUtils.mkdir_p(user_dir)
      File.write(File.join(user_dir, "#{key}.json"), JSON.pretty_generate(key => config))
      key
    end

    def user_dir
      base = ENV['XDG_DATA_HOME'] || File.join(Dir.home, '.local', 'share')
      File.join(base, 'exhibit-rb', 'configurations')
    end

    def load_bundled
      [File.expand_path('../data/configurations.json', __dir__),
       File.expand_path('../configurations.json', __dir__)].each do |path|
        if File.exist?(path) then @configs.merge!(JSON.parse(File.read(path))) end
      end
    end

    def load_user
      FileUtils.mkdir_p(user_dir)
      Dir.glob(File.join(user_dir, '*.json')).each { |f| merge_user_file(f) }
    end

    def merge_user_file(path)
      config = JSON.parse(File.read(path))
      if valid?(config) then @configs.merge!(config) end
    rescue JSON::ParserError
      nil
    end

    def valid?(config)
      first = config.values.first
      first.is_a?(Hash) && REQUIRED_KEYS.all? { |k| first.key?(k) }
    end
  end
end
