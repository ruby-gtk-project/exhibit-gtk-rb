# frozen_string_literal: true

# Keyboard-shortcuts window. Gtk::ShortcutsWindow is broken in the Ruby bindings
# (and deprecated upstream), so this is a plain modal window of Adwaita
# preference groups, one row per shortcut with a Gtk::ShortcutLabel.

require 'gtk4'
require 'adwaita'

module Exhibit
  class ShortcutsDialog
    GROUPS = [
      ['Views', [
        ['<primary>1', 'Front View'],
        ['<primary>3', 'Right View'],
        ['<primary>7', 'Top View'],
        ['<primary>9', 'Isometric View'],
        ['<primary>5', 'Toggle Orthographic'],
      ]],
      ['Move', [
        ['<primary>w', 'Forward'],
        ['<primary>a', 'Left'],
        ['<primary>s', 'Backward'],
        ['<primary>d', 'Right'],
      ]],
      ['Tilt', [
        ['<primary>Up', 'Up'],
        ['<primary>Down', 'Down'],
        ['<primary>Left', 'Left'],
        ['<primary>Right', 'Right'],
      ]],
      ['General', [
        ['F1', 'Help'],
        ['<primary>question', 'Keyboard Shortcuts'],
        ['<primary><shift>n', 'New Window'],
        ['<primary><shift>e', 'Open in External App'],
        ['<primary>q', 'Quit'],
      ]],
    ].freeze

    def initialize(parent)
      @parent = parent
    end

    def present = window.present

    def window
      @window ||= Gtk::Window.new.tap do |w|
        w.title = 'Keyboard Shortcuts'
        w.transient_for = @parent
        w.modal = true
        w.set_default_size(420, 560)
        w.child = layout
      end
    end

    def layout
      Adwaita::ToolbarView.new.tap do |tv|
        tv.add_top_bar(Adwaita::HeaderBar.new)
        tv.content = page
      end
    end

    def page
      Adwaita::PreferencesPage.new.tap do |p|
        GROUPS.each { |title, items| p.add(group(title, items)) }
      end
    end

    def group(title, items)
      Adwaita::PreferencesGroup.new.tap do |g|
        g.title = title
        items.each { |accel, label| g.add(row(accel, label)) }
      end
    end

    def row(accel, label)
      Adwaita::ActionRow.new.tap do |r|
        r.title = label
        r.add_suffix(Gtk::ShortcutLabel.new(accel).tap { |s| s.valign = :center })
      end
    end
  end
end
