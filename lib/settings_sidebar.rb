# frozen_string_literal: true

# The settings sidebar: an Adwaita ViewStack (Render / Model / Scene / More) of
# preference groups, every row two-way bound to the SettingsModel. A row change
# calls model.set; a model change (including the startup sync) sets the row. The
# @syncing guard stops the two directions from ping-ponging.

require 'gtk4'
require 'adwaita'
require_relative 'file_row'
require_relative 'hdri_manager'

module Exhibit
  class SettingsSidebar
    UP_DIRECTIONS = %w[-X +X -Y +Y -Z +Z].freeze
    SPRITE_TYPES = %w[sphere gaussian].freeze

    def initialize(model, viewer)
      @model = model
      @viewer = viewer
      @syncing = false
      @playing = false
    end

    # Called by MainWindow after a file loads: show the animation group and set
    # the timeline bounds if the scene is animated, hide it otherwise.
    def refresh_animation
      range = @viewer.animation_range
      animated = range[1] > range[0]
      animation_group.visible = animated
      if animated
        stop_play
        time_adjustment.configure(range[0], range[0], range[1], (range[1] - range[0]) / 200, 0.1, 0)
      end
    end

    def build
      root.tap do |b|
        b.append(switcher)
        b.append(view_stack)

        view_stack.tap do |vs|
          add_page(vs, render_page, 'render', 'Render', 'video-display-symbolic')
          add_page(vs, model_page, 'model', 'Model', 'applications-graphics-symbolic')
          add_page(vs, scene_page, 'scene', 'Scene', 'view-paged-symbolic')
          add_page(vs, more_page, 'more', 'More', 'view-more-symbolic')
        end
      end
    end

    def add_page(stack, child, name, title, icon)
      stack.add_titled(child, name, title).tap { |page| page.icon_name = icon }
    end

    # ---- two-way binding -------------------------------------------------------

    def push(key, value)
      unless @syncing
        @model.set(key, value)
      end
    end

    def pull
      @syncing = true
      yield
    ensure
      @syncing = false
    end

    def switch_row(title, key)
      Adwaita::SwitchRow.new.tap do |r|
        r.title = title
        r.signal_connect('notify::active') { push(key, r.active?) }
        @model.on_change { |k, v, _c| if k == key then pull { r.active = v } end }
      end
    end

    def spin_row(title, key, lower, upper, step, digits)
      Adwaita::SpinRow.new(Gtk::Adjustment.new(lower, lower, upper, step, step * 10, 0), step, digits).tap do |r|
        r.title = title
        r.signal_connect('notify::value') { push(key, r.value.round(digits)) }
        @model.on_change { |k, v, _c| if k == key then pull { r.value = v } end }
      end
    end

    def combo_row(title, key, labels, values)
      Adwaita::ComboRow.new.tap do |r|
        r.title = title
        r.model = Gtk::StringList.new(labels)
        r.signal_connect('notify::selected') { push(key, values[r.selected]) }
        @model.on_change { |k, v, _c| if k == key then pull { r.selected = values.index(v) || 0 } end }
      end
    end

    def color_row(title, key)
      Adwaita::ActionRow.new.tap { |r| r.title = title; r.add_suffix(color_button(key)) }
    end

    def color_button(key)
      Gtk::ColorDialogButton.new(Gtk::ColorDialog.new).tap do |b|
        b.valign = :center
        b.signal_connect('notify::rgba') { push(key, [b.rgba.red, b.rgba.green, b.rgba.blue]) }
        @model.on_change { |k, v, _c| if k == key then pull { b.rgba = Gdk::RGBA.new(v[0], v[1], v[2], 1.0) } end }
      end
    end

    def group(title)
      Adwaita::PreferencesGroup.new.tap { |g| g.title = title }
    end

    # ---- pages -----------------------------------------------------------------

    def render_page
      Adwaita::PreferencesPage.new.tap do |p|
        p.add(rendering_group)
        p.add(model_rendering_group)
        p.add(points_group)
      end
    end

    def model_page
      Adwaita::PreferencesPage.new.tap do |p|
        p.add(material_group)
        p.add(model_color_group)
        p.add(armature_group)
      end
    end

    def scene_page
      Adwaita::PreferencesPage.new.tap do |p|
        p.add(grid_group)
        p.add(background_group)
        p.add(scene_color_group)
      end
    end

    def more_page
      Adwaita::PreferencesPage.new.tap do |p|
        p.add(navigation_group)
        p.add(animation_group)
        p.add(loading_group)
      end
    end

    # ---- groups ----------------------------------------------------------------

    def rendering_group
      group('Rendering').tap do |g|
        g.add(switch_row('Translucency', 'translucency-support'))
        g.add(switch_row('Tone Mapping', 'tone-mapping'))
        g.add(switch_row('Ambient Occlusion', 'ambient-occlusion'))
        g.add(switch_row('Anti Aliasing', 'anti-aliasing'))
        g.add(switch_row('Light with HDRI', 'hdri-ambient'))
        g.add(spin_row('Light Intensity', 'light-intensity', 0.0, 10.0, 0.1, 2))
      end
    end

    def model_rendering_group
      group('Model Rendering').tap do |g|
        g.add(switch_row('Show All Edges', 'show-edges'))
        g.add(spin_row('Edges Width', 'edges-width', 0.0, 10.0, 0.5, 1))
      end
    end

    def points_group
      group('Points').tap do |g|
        g.add(switch_row('Show Point Sprites', 'sprite-enabled'))
        g.add(combo_row('Point Sprites Type', 'sprites-type', %w[Sphere Gaussian], SPRITE_TYPES))
        g.add(spin_row('Sprite Size', 'sprites-size', 0.0, 10.0, 0.1, 2))
        g.add(spin_row('Points Size', 'point-size', 0.0, 20.0, 0.5, 1))
      end
    end

    def material_group
      group('Material').tap do |g|
        g.add(spin_row('Metallic', 'model-metallic', 0.0, 1.0, 0.05, 2))
        g.add(spin_row('Roughness', 'model-roughness', 0.0, 1.0, 0.05, 2))
        g.add(spin_row('Opacity', 'model-opacity', 0.0, 1.0, 0.05, 2))
      end
    end

    def model_color_group
      group('Color').tap do |g|
        g.add(coloration_row)
        g.add(model_color_action_row)
      end
    end

    def model_color_action_row = @model_color_action_row ||= color_row('Model Color', 'model-color')

    # Compound control: "Coloration" maps one combo onto three scivis settings
    # (component / cells / enabled) and gates the Model Color row, mirroring
    # Exhibit's on_scivis_component_combo_changed.
    def coloration_row
      Adwaita::ComboRow.new.tap do |r|
        r.title = 'Coloration'
        r.model = Gtk::StringList.new(%w[Custom Normal Magnitude Direct])
        r.signal_connect('notify::selected') { push_coloration(r.selected) }
        @model.on_change do |k, _v, _c|
          if %w[scivis-component cells].include?(k) then pull { apply_coloration_to(r) } end
        end
      end
    end

    def push_coloration(selected)
      unless @syncing
        if selected.zero?
          @model.set('scivis-component', -1)
          @model.set('cells', true)
          @model.set('scivis-enabled', false)
        else
          @model.set('scivis-component', -(selected - 1))
          @model.set('cells', false)
          @model.set('scivis-enabled', true)
        end
        model_color_action_row.sensitive = selected.zero?
      end
    end

    def apply_coloration_to(row)
      index = coloration_index
      row.selected = index
      model_color_action_row.sensitive = index.zero?
    end

    def coloration_index
      if @model.get('scivis-component') == -1 && @model.get('cells')
        0
      else
        -@model.get('scivis-component') + 1
      end
    end

    def armature_group
      group('Armature').tap { |g| g.add(switch_row('Show Armature', 'armature-enable')) }
    end

    def grid_group
      group('Grid').tap do |g|
        g.add(switch_row('View Grid', 'grid'))
        g.add(switch_row('Grid Absolute', 'grid-absolute'))
      end
    end

    def background_group
      group('Background').tap do |g|
        g.add(switch_row('HDRI as Background', 'hdri-skybox'))
        g.add(hdri_file_row.build)
        g.add(switch_row('Blur Background', 'blur-background'))
        g.add(spin_row('Blur Circle of Confusion', 'blur-coc', 0.0, 100.0, 1.0, 0))
      end
    end

    def hdri_file_row
      @hdri_file_row ||= FileRow.new(
        title: 'HDRI Image',
        patterns: %w[hdr exr],
        on_added: ->(path) { set_hdri(path) },
        on_deleted: -> { set_hdri('') },
      ).tap { |fr| HdriManager.list.each { |p| fr.add_suggestion(p) } }
    end

    def set_hdri(path)
      @model.set('hdri-file', path)
      @model.set('hdri-skybox', !path.empty?)
    end

    def scene_color_group
      group('Color').tap do |g|
        g.add(switch_row('Use Custom Color', 'use-color'))
        g.add(color_row('Background Color', 'bg-color'))
      end
    end

    def navigation_group
      group('Navigation').tap do |g|
        g.add(switch_row('Always Point Up', 'point-up'))
        g.add(combo_row('Up Direction', 'up', UP_DIRECTIONS, UP_DIRECTIONS))
      end
    end

    def loading_group
      group('Loading').tap do |g|
        g.add(switch_row('Automatic Settings', 'auto-best'))
        g.add(switch_row('Reload On Change', 'auto-reload'))
      end
    end

    # ---- animation -------------------------------------------------------------

    def animation_group
      @animation_group ||= group('Animation').tap do |g|
        g.visible = false
        g.add(animation_index_row)
        g.add(timeline_row)
      end
    end

    def animation_index_row
      Adwaita::SpinRow.new(Gtk::Adjustment.new(0, 0, 99, 1, 5, 0), 1, 0).tap do |r|
        r.title = 'Animation Index'
        r.signal_connect('notify::value') { on_animation_index(r.value.to_i) }
      end
    end

    # Changing the index needs a reload — f3d reads scene.animation.index when
    # the scene is added, not live.
    def on_animation_index(index)
      unless @syncing
        @model.set('animation-index', index)
        @viewer.reload
        refresh_animation
      end
    end

    def timeline_row
      Adwaita::ActionRow.new.tap do |r|
        r.title = 'Timeline'
        r.add_prefix(play_button)
        r.add_suffix(time_scale)
      end
    end

    def on_scrub
      unless @playing
        @viewer.animation_time = time_adjustment.value
      end
    end

    def toggle_play
      if @playing then stop_play else start_play end
    end

    def start_play
      @playing = true
      play_button.icon_name = 'media-playback-pause-symbolic'
      GLib::Timeout.add(33) { advance_play }
    end

    def stop_play
      @playing = false
      play_button.icon_name = 'media-playback-start-symbolic'
    end

    def advance_play
      step = (time_adjustment.upper - time_adjustment.lower) / 200
      t = time_adjustment.value + step
      time_adjustment.value = t >= time_adjustment.upper ? time_adjustment.lower : t
      @viewer.animation_time = time_adjustment.value
      @playing
    end

    def play_button
      @play_button ||= Gtk::Button.new.tap do |b|
        b.icon_name = 'media-playback-start-symbolic'
        b.valign = :center
        b.add_css_class('flat')
        b.signal_connect('clicked') { toggle_play }
      end
    end

    def time_scale
      @time_scale ||= Gtk::Scale.new(:horizontal, time_adjustment).tap do |s|
        s.hexpand = true
        s.width_request = 160
        s.draw_value = false
        s.signal_connect('value-changed') { on_scrub }
      end
    end

    def time_adjustment = @time_adjustment ||= Gtk::Adjustment.new(0, 0, 1, 0.01, 0.1, 0)

    # ---- widgets ---------------------------------------------------------------

    def root = @root ||= Gtk::Box.new(:vertical, 0)
    def view_stack = @view_stack ||= Adwaita::ViewStack.new.tap { |s| s.vexpand = true }

    def switcher
      @switcher ||= Adwaita::ViewSwitcher.new.tap do |sw|
        sw.stack = view_stack
        sw.policy = :wide
        sw.margin_top = 6
        sw.margin_bottom = 6
      end
    end
  end
end
