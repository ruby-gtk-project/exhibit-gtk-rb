# frozen_string_literal: true

# A single viewer window. An Adwaita overlay split view holds the 3D viewer as
# content and (from Phase 3) the settings sidebar. A Gtk::Stack switches the
# content between the startup / loading / error / 3d states.

require 'gtk4'
require 'adwaita'
require_relative 'f3d_viewer'
require_relative 'settings_model'
require_relative 'settings_sidebar'
require_relative 'shortcuts_dialog'

module Exhibit
  class MainWindow
    def initialize(application:, file: nil)
      @application = application
      @file = file
      @loaded_once = false
    end

    def build
      window.tap do
        toast_overlay.tap { |to| to.child = split_view }

        split_view.tap do |sv|
          sv.content = stack
          sv.sidebar = settings_sidebar.build
        end

        header_bar.tap do |hb|
          hb.pack_start(home_button)
          hb.pack_start(open_button)
          hb.pack_end(menu_button)
          hb.pack_end(sidebar_button)
          hb.pack_end(export_button)
        end

        add_action('save-image') { save_image }
        add_view_action('show-shortcuts', '<primary>question') { show_shortcuts }

        home_button.signal_connect('clicked') { viewer.reset_to_bounds }
        open_button.signal_connect('clicked') { open_file_chooser }
        startup_open_button.signal_connect('clicked') { open_file_chooser }
        error_open_button.signal_connect('clicked') { open_file_chooser }
        sidebar_button.signal_connect('clicked') { split_view.show_sidebar = !split_view.show_sidebar? }

        stack.tap do |s|
          s.add_named(startup_page, 'startup')
          s.add_named(loading_page, 'loading')
          s.add_named(error_page, 'error')
          s.add_named(viewer.build, '3d')
        end

        window.add_controller(drop_target)
        drop_target.signal_connect('drop') { |_t, value, _x, _y| on_drop(value) }

        # Forward every :view setting to the viewer as an f3d option, then push
        # the defaults so the engine starts configured (grid, AA, materials, …).
        settings.on_change do |key, value, _category|
          settings.view_option(key).then { |option| if option then viewer.set_option(option, value) end }
        end
        # The background is computed from use-color + bg-color + the theme.
        settings.on_change { |key, _v, _c| if %w[use-color bg-color].include?(key) then update_background_color end }
        style_manager.signal_connect('notify::dark') { update_background_color }
        settings.sync
        update_background_color

        setup_camera_actions

        @file.then { |f| if f then load_file(f) else show('startup') end }
      end
    end

    # ---- file loading ----------------------------------------------------------

    def load_file(path)
      @file = path
      show('3d') # map the GLArea so it realizes and the f3d engine comes up
      viewer.load(path)
    end

    def open_file_chooser
      Gtk::FileDialog.new.tap do |d|
        d.title = 'Open Model'
        d.open(window, nil) { |dialog, result| on_open_response(dialog, result) }
      end
    end

    def on_open_response(dialog, result)
      finished_file(dialog, result).then { |f| if f then load_file(f.path) end }
    end

    def finished_file(dialog, result)
      dialog.open_finish(result)
    rescue StandardError
      nil
    end

    def on_drop(value)
      value.files.first.then { |f| if f then load_file(f.path) end }
      true
    end

    def on_viewer_loaded(path)
      @loaded_once = true
      window.title = "Exhibit — #{File.basename(path)}"
      show('3d')
      settings_sidebar.refresh_animation
      update_background_color # a reload re-inits the engine, resetting the bg
    end

    # Effective background: the custom colour when "Use Custom Color" is on,
    # otherwise follow the Adwaita light/dark theme (Exhibit's grey / white).
    def update_background_color
      if settings.get('use-color')
        color = settings.get('bg-color')
      elsif style_manager.dark?
        color = [0.117, 0.117, 0.117]
      else
        color = [1.0, 1.0, 1.0]
      end
      viewer.set_option('render.background.color', color)
    end

    def style_manager = @style_manager ||= Adwaita::StyleManager.default

    def on_viewer_error(path)
      if @loaded_once then send_toast("Can't open #{File.basename(path)}") else show('error') end
    end

    def send_toast(message) = toast_overlay.add_toast(Adwaita::Toast.new(message))

    def show(name) = stack.set_visible_child_name(name)

    # ---- camera view + navigation actions (keyboard) ---------------------------

    def setup_camera_actions
      add_view_action('front-view', '<primary>1') { viewer.front_view }
      add_view_action('right-view', '<primary>3') { viewer.right_view }
      add_view_action('top-view', '<primary>7') { viewer.top_view }
      add_view_action('isometric-view', '<primary>9') { viewer.isometric_view }
      add_view_action('toggle-orthographic', '<primary>5') { toggle_orthographic }
      add_view_action('move-forward', '<primary>w') { viewer.pan_by(0, 0, 1) }
      add_view_action('move-left', '<primary>a') { viewer.pan_by(-1, 0, 0) }
      add_view_action('move-backward', '<primary>s') { viewer.pan_by(0, 0, -1) }
      add_view_action('move-right', '<primary>d') { viewer.pan_by(1, 0, 0) }
      add_view_action('tilt-up', '<primary>Up') { viewer.tilt_by(0, 1) }
      add_view_action('tilt-down', '<primary>Down') { viewer.tilt_by(0, -1) }
      add_view_action('tilt-left', '<primary>Left') { viewer.tilt_by(-1, 0) }
      add_view_action('tilt-right', '<primary>Right') { viewer.tilt_by(1, 0) }
    end

    def add_action(name, &block)
      Gio::SimpleAction.new(name).tap do |action|
        action.signal_connect('activate') { block.call }
        window.add_action(action)
      end
    end

    def add_view_action(name, accel, &block)
      add_action(name, &block)
      @application.set_accels_for_action("win.#{name}", [accel])
    end

    def toggle_orthographic = settings.set('orthographic', !settings.get('orthographic'))

    # ---- image export ----------------------------------------------------------

    def save_image
      Gtk::FileDialog.new.tap do |d|
        d.title = 'Save Image'
        d.initial_name = "#{export_basename}.png"
        d.save(window, nil) { |dialog, result| on_save_response(dialog, result) }
      end
    end

    def export_basename
      base = 'exhibit'
      @file.then { |f| if f then base = File.basename(f, '.*') end }
      base
    end

    def on_save_response(dialog, result)
      saved_path(dialog, result).then { |path| if path then export_to(path) end }
    end

    def saved_path(dialog, result)
      dialog.save_finish(result)&.path
    rescue StandardError
      nil
    end

    def export_to(path)
      if viewer.save_png(path)
        send_open_toast(path)
      else
        send_toast("Couldn't save image")
      end
    end

    def send_open_toast(path)
      Adwaita::Toast.new('Image saved').tap do |t|
        t.button_label = 'Open'
        t.action_name = 'app.show-image-externally'
        t.action_target = GLib::Variant.new(path)
        toast_overlay.add_toast(t)
      end
    end

    # ---- widgets ---------------------------------------------------------------

    def window
      # Gtk::ApplicationWindow (Adwaita's is broken in the bindings) shows a
      # default titlebar; make our HeaderBar *be* the titlebar so we get one
      # header, not a window-in-a-window.
      @window ||= Gtk::ApplicationWindow.new(@application).tap do |w|
        w.title = 'Exhibit'
        w.set_default_size(840, 600)
        w.titlebar = header_bar
        w.child = toast_overlay
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    def split_view
      @split_view ||= Adwaita::OverlaySplitView.new.tap do |sv|
        sv.max_sidebar_width = 360
        sv.sidebar_position = :end
      end
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def stack = @stack ||= Gtk::Stack.new
    def settings = @settings ||= SettingsModel.new
    def settings_sidebar = @settings_sidebar ||= SettingsSidebar.new(settings, viewer)

    def viewer
      @viewer ||= F3DViewer.new(
        file: @file,
        on_loaded: method(:on_viewer_loaded),
        on_error: method(:on_viewer_error),
      )
    end

    def home_button
      @home_button ||= Gtk::Button.new.tap do |b|
        b.icon_name = 'go-home-symbolic'
        b.tooltip_text = 'Reset View'
      end
    end

    def open_button
      @open_button ||= Gtk::Button.new.tap do |b|
        b.icon_name = 'document-open-symbolic'
        b.tooltip_text = 'Open Model'
      end
    end

    def sidebar_button
      @sidebar_button ||= Gtk::Button.new.tap do |b|
        b.icon_name = 'sidebar-show-right-symbolic'
        b.tooltip_text = 'Toggle Sidebar'
      end
    end

    def export_button
      @export_button ||= Gtk::Button.new.tap do |b|
        b.icon_name = 'camera-photo-symbolic'
        b.tooltip_text = 'Save as Image'
        b.action_name = 'win.save-image'
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |b|
        b.icon_name = 'open-menu-symbolic'
        b.menu_model = primary_menu
      end
    end

    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |m|
        m.append('New Window', 'app.new-window')
        m.append('Save as Image…', 'win.save-image')
        m.append_submenu('Appearance', theme_menu)
        m.append_section(nil, help_section)
        m.append('Quit', 'app.quit')
      end
    end

    def help_section
      Gio::Menu.new.tap do |m|
        m.append('Keyboard Shortcuts', 'win.show-shortcuts')
        m.append('About Exhibit', 'app.about')
      end
    end

    def show_shortcuts = ShortcutsDialog.new(window).present

    def theme_menu
      Gio::Menu.new.tap do |m|
        m.append('Follow System', 'app.theme::follow')
        m.append('Light', 'app.theme::light')
        m.append('Dark', 'app.theme::dark')
      end
    end

    def drop_target = @drop_target ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)

    def startup_page
      @startup_page ||= Adwaita::StatusPage.new.tap do |sp|
        sp.icon_name = 'applications-graphics-symbolic'
        sp.title = 'Exhibit'
        sp.description = 'Open or drop a 3D model to view it'
        sp.child = startup_open_button
      end
    end

    def startup_open_button
      @startup_open_button ||= Gtk::Button.new(label: 'Open Model…').tap do |b|
        b.halign = :center
        b.add_css_class('suggested-action')
        b.add_css_class('pill')
      end
    end

    def loading_page
      @loading_page ||= Gtk::Label.new('Loading…').tap do |l|
        l.halign = :center
        l.valign = :center
      end
    end

    def error_page
      @error_page ||= Adwaita::StatusPage.new.tap do |sp|
        sp.icon_name = 'dialog-error-symbolic'
        sp.title = 'Error Loading File'
        sp.description = 'That file could not be opened as a 3D model'
        sp.child = error_open_button
      end
    end

    def error_open_button
      @error_open_button ||= Gtk::Button.new(label: 'Open Another…').tap do |b|
        b.halign = :center
        b.add_css_class('pill')
      end
    end

  end
end
