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
require_relative 'configuration_store'
require_relative 'save_preset_dialog'
require_relative 'app_settings'

module Exhibit
  class MainWindow
    def initialize(application:, file: nil)
      @application = application
      @file = file
      @loaded_once = false
    end

    def build
      window.tap do
        toast_overlay.tap { |to| to.child = breakpoint_bin }

        # Adaptive layout: below 600px the split view collapses so the sidebar
        # becomes an overlay (BreakpointBin lets us do this without an Adw window).
        breakpoint_bin.tap do |bin|
          bin.child = split_view
          bin.add_breakpoint(collapse_breakpoint)
        end

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

        add_action('open') { open_file_chooser }
        add_action('add-new') { add_file_chooser }
        add_view_action('open-external', '<primary><shift>e') { open_external }
        add_action('save-image') { save_image }
        add_view_action('show-shortcuts', '<primary>question') { show_shortcuts }
        window.add_action(orthographic_action)
        @application.set_accels_for_action('win.orthographic', ['<primary>5'])
        window.add_action(preset_action)
        add_action('save-preset') { show_save_preset }
        # Keep the orthographic menu-toggle in sync when a preset changes it.
        settings.on_change { |key, value, _c| if key == 'orthographic' then orthographic_action.state = GLib::Variant.new(value) end }
        # Deviating from the active preset flips it to "Custom".
        settings.on_change do |_key, _v, category|
          if %i[view other].include?(category) && !@applying_preset then check_preset_deviation end
        end

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
        # Up direction is read at scene-add time → reload; auto-reload toggles the watcher.
        settings.on_change do |key, _v, _c|
          if key == 'up' then reload_preserving end
          if key == 'auto-reload' then update_auto_reload end
        end
        settings.sync
        update_background_color

        setup_camera_actions

        # Restore persisted window/session state and save it on close.
        split_view.show_sidebar = AppSettings.get('sidebar')
        settings.set('auto-best', AppSettings.get('auto-best'))
        window.signal_connect('close-request') { on_close }

        @file.then { |f| if f then load_file(f) else show('startup') end }
      end
    end

    def on_close
      AppSettings.update(
        'width' => window.width,
        'height' => window.height,
        'sidebar' => split_view.show_sidebar?,
        'auto-best' => settings.get('auto-best'),
      )
      false # allow the close to proceed
    end

    # ---- file loading ----------------------------------------------------------

    def load_file(path)
      @file = path
      if settings.get('auto-best') then apply_best_preset(path) end
      show('3d') # map the GLArea so it realizes and the f3d engine comes up
      viewer.load(path)
    end

    # ---- presets / configurations ----------------------------------------------

    def presets = @presets ||= ConfigurationStore.new

    def preset_action
      @preset_action ||= Gio::SimpleAction.new('preset', GLib::VariantType.new('s'), GLib::Variant.new('general')).tap do |a|
        a.signal_connect('change-state') do |action, state|
          key = as_string(state)
          action.state = GLib::Variant.new(key)
          apply_preset(key)
        end
      end
    end

    # Ruby-GNOME hands a stateful action's value back as a String in some paths
    # and a GLib::Variant in others; normalise to a String.
    def as_string(value)
      if value.is_a?(String) then value else value.get_string end
    end

    def apply_preset(key)
      unless key == 'custom'
        presets[key].then do |config|
          if config then set_preset_settings(config) end
        end
      end
    end

    def set_preset_settings(config)
      @applying_preset = true
      settings.apply_all(settings.customizable_defaults)
      settings.apply_all(config['view-settings'])
      settings.apply_all(config['other-settings'])
      @applying_preset = false
    end

    def apply_best_preset(path)
      key = presets.match(path)
      preset_action.state = GLib::Variant.new(key)
      apply_preset(key)
    end

    def check_preset_deviation
      key = as_string(preset_action.state)
      unless key == 'custom'
        if deviates_from?(key) then preset_action.state = GLib::Variant.new('custom') end
      end
    end

    def deviates_from?(key)
      config = presets[key]
      expected = settings.customizable_defaults.merge(config['view-settings']).merge(config['other-settings'])
      expected.any? { |k, v| settings.get(k) != v }
    end

    def show_save_preset
      SavePresetDialog.new(parent: window, on_save: method(:save_preset)).present
    end

    def save_preset(name, extensions)
      key = presets.save(name, extensions, settings.view_settings, settings.other_settings)
      preset_section.append(presets.name_of(key), "win.preset::#{key}")
      preset_action.state = GLib::Variant.new(key)
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

    IMAGE_EXTS = %w[hdr exr png jpg jpeg pnm tiff bmp].freeze

    def on_drop(value)
      value.files.first.then { |f| if f then dispatch_drop(f.path) end }
      true
    end

    # Images dropped on the view become the HDRI/skybox (like the fork); other
    # supported files load as models.
    def dispatch_drop(path)
      if IMAGE_EXTS.include?(File.extname(path).delete('.').downcase)
        settings_sidebar.hdri_file_row.pick(path)
      else
        load_file(path)
      end
    end

    def on_viewer_loaded(path)
      @loaded_once = true
      @file_stamp = file_mtime(path)
      window.title = "Exhibit — #{File.basename(path)}"
      show('3d')
      settings_sidebar.refresh_animation
      update_background_color # a reload re-inits the engine, resetting the bg
    end

    # ---- reload + auto-reload ---------------------------------------------------

    def reload_preserving
      @file.then { |f| if f then viewer.reload(preserve: true) end }
    end

    def update_auto_reload
      if settings.get('auto-reload') then start_file_watch else @watch_running = false end
    end

    def start_file_watch
      unless @watch_running
        @watch_running = true
        GLib::Timeout.add(500) { tick_file_watch }
      end
    end

    def tick_file_watch
      if @watch_running then check_file_changed end
      @watch_running
    end

    def check_file_changed
      @file.then do |f|
        if f
          stamp = file_mtime(f)
          if stamp && stamp != @file_stamp
            @file_stamp = stamp
            reload_preserving
          end
        end
      end
    end

    def file_mtime(path)
      File.mtime(path).to_f
    rescue StandardError
      nil
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

    def orthographic_action
      @orthographic_action ||= Gio::SimpleAction.new('orthographic', nil, GLib::Variant.new(settings.get('orthographic'))).tap do |a|
        a.signal_connect('change-state') do |action, state|
          value = as_bool(state)
          action.state = GLib::Variant.new(value)
          settings.set('orthographic', value)
        end
      end
    end

    def as_bool(value)
      if value.is_a?(GLib::Variant) then value.get_boolean else value end
    end

    # ---- add file / open externally --------------------------------------------

    def add_file_chooser
      Gtk::FileDialog.new.tap do |d|
        d.title = 'Add File to Scene'
        d.open(window, nil) { |dialog, result| on_add_response(dialog, result) }
      end
    end

    def on_add_response(dialog, result)
      finished_file(dialog, result).then { |f| if f then viewer.add_file(f.path) end }
    end

    def open_external
      @file.then { |f| if f then Gtk::FileLauncher.new(Gio::File.new_for_path(f)).launch(window, nil) {} end }
    end

    def breakpoint_bin = @breakpoint_bin ||= Adwaita::BreakpointBin.new.tap { |b| b.set_size_request(360, 200) }

    def collapse_breakpoint
      Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse('max-width: 600px')).tap do |bp|
        bp.add_setter(split_view, 'collapsed', true)
      end
    end

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
        w.set_default_size(AppSettings.get('width'), AppSettings.get('height'))
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
        m.append_section(nil, file_section)
        m.append_submenu('Presets', preset_menu)
        m.append_section(nil, view_section)
        m.append_section(nil, folder_section)
        m.append_section(nil, help_section)
        m.append('Quit', 'app.quit')
      end
    end

    def file_section
      Gio::Menu.new.tap do |m|
        m.append('New Window', 'app.new-window')
        m.append('Load New File', 'win.open')
        m.append('Add File to Scene', 'win.add-new')
        m.append('Export Image…', 'win.save-image')
        m.append('Open in External App', 'win.open-external')
      end
    end

    def view_section
      Gio::Menu.new.tap do |m|
        m.append('Orthographic', 'win.orthographic')
        m.append_submenu('Appearance', theme_menu)
      end
    end

    def folder_section
      Gio::Menu.new.tap do |m|
        m.append('Open HDRI Folder', 'app.open-hdri-folder')
        m.append('Open Configurations Folder', 'app.open-configs-folder')
      end
    end

    def preset_menu
      @preset_menu ||= Gio::Menu.new.tap do |m|
        m.append_section(nil, preset_section)
        m.append('Save Current as Preset…', 'win.save-preset')
      end
    end

    def preset_section
      @preset_section ||= Gio::Menu.new.tap do |m|
        m.append('Custom', 'win.preset::custom')
        presets.keys.each { |key| m.append(presets.name_of(key), "win.preset::#{key}") }
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
