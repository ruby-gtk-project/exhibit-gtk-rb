# frozen_string_literal: true

# Modal dialog to save the current settings as a named user preset. Collects a
# name and a comma-separated list of extensions the preset should auto-apply to,
# then calls on_save.(name, extensions).

require 'gtk4'
require 'adwaita'

module Exhibit
  class SavePresetDialog
    def initialize(parent:, on_save:, supported: [])
      @parent = parent
      @on_save = on_save
      @supported = supported
    end

    def present = window.present

    def on_save_clicked
      name_row.text.strip.then do |name|
        if name.empty? then next_noop else commit(name) end
      end
    end

    def next_noop = nil

    def commit(name)
      @on_save.call(name, extensions_row.text)
      window.close
    end

    def update_sensitivity = save_button.sensitive = !name_row.text.strip.empty?

    def window
      @window ||= Gtk::Window.new.tap do |w|
        w.title = 'Save Preset'
        w.transient_for = @parent
        w.modal = true
        w.set_default_size(400, 240)
        w.child = layout
      end
    end

    def layout
      Adwaita::ToolbarView.new.tap do |tv|
        tv.add_top_bar(header)
        tv.content = page
      end
    end

    def header
      Adwaita::HeaderBar.new.tap { |h| h.pack_end(save_button) }
    end

    def save_button
      @save_button ||= Gtk::Button.new(label: 'Save').tap do |b|
        b.add_css_class('suggested-action')
        b.sensitive = false
        b.signal_connect('clicked') { on_save_clicked }
      end
    end

    def page
      Adwaita::PreferencesPage.new.tap { |p| p.add(group) }
    end

    def group
      Adwaita::PreferencesGroup.new.tap do |g|
        g.add(name_row)
        g.add(extensions_row)
      end
    end

    def name_row
      @name_row ||= Adwaita::EntryRow.new.tap do |r|
        r.title = 'Name'
        r.signal_connect('changed') { update_sensitivity }
      end
    end

    def extensions_row
      @extensions_row ||= Adwaita::EntryRow.new.tap do |r|
        r.title = 'Extensions (e.g. stl, obj)'
        r.signal_connect('changed') { validate_extensions(r) }
      end
    end

    # Flag the row when any entered extension isn't one f3d can read.
    def validate_extensions(row)
      entered = row.text.split(',').map { |e| e.strip.downcase }.reject(&:empty?)
      if entered.empty? || entered.all? { |e| @supported.include?(e) }
        row.remove_css_class('error')
      else
        row.add_css_class('error')
      end
    end
  end
end
