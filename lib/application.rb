# frozen_string_literal: true

# Exhibit-rb — Ruby GTK4 port of nokse22's Exhibit 3D viewer.
# The application owns global actions and spawns one MainWindow per file
# (HANDLES_OPEN → the 'open' signal fires once with the files passed on argv).

require 'gtk4'
require 'adwaita'
require 'fileutils'
require_relative 'main_window'
require_relative 'hdri_manager'
require_relative 'app_settings'

module Exhibit
  class Application
    APP_ID = 'io.github.ruby_gtk_project.Exhibit'

    def build
      HdriManager.seed
      apply_theme(AppSettings.get('theme'))
      app.tap do |a|
        a.signal_connect('activate') { open_window(nil) }
        a.signal_connect('open') do |_app, files, _n, _hint|
          files.each { |file| open_window(file.path) }
        end
      end
    end

    # GApplication.run expects argv[0] to be the program name (C convention);
    # Ruby's ARGV omits it, so prepend $0 or files get eaten as argv[0] and the
    # 'open' signal never fires.
    def run(argv = ARGV) = app.run([$PROGRAM_NAME, *argv])

    def app
      @app ||= Gtk::Application.new(APP_ID, :handles_open).tap do |a|
        quit = Gio::SimpleAction.new('quit')
        quit.signal_connect('activate') { a.quit }
        a.add_action(quit)
        a.set_accels_for_action('app.quit', ['<Primary>q'])
        a.add_action(theme_action)
        a.add_action(show_image_action)
        a.add_action(about_action)
        a.add_action(new_window_action)
        a.set_accels_for_action('app.new-window', ['<Primary><Shift>n'])
        a.add_action(folder_action('open-hdri-folder') { HdriManager.dir })
        a.add_action(folder_action('open-configs-folder') { configs_dir })
      end
    end

    # An action that opens a directory in the file manager (creating it first).
    def folder_action(name, &dir)
      Gio::SimpleAction.new(name).tap do |action|
        action.signal_connect('activate') { launch_dir(dir.call) }
      end
    end

    def launch_dir(dir)
      FileUtils.mkdir_p(dir)
      Gtk::FileLauncher.new(Gio::File.new_for_path(dir)).launch(app.active_window, nil) {}
    end

    def configs_dir
      base = ENV['XDG_DATA_HOME'] || File.join(Dir.home, '.local', 'share')
      File.join(base, 'exhibit-rb', 'configurations')
    end

    def about_action
      Gio::SimpleAction.new('about').tap { |action| action.signal_connect('activate') { show_about } }
    end

    def new_window_action
      Gio::SimpleAction.new('new-window').tap { |action| action.signal_connect('activate') { open_window(nil) } }
    end

    def show_about
      Adwaita::AboutDialog.new.tap do |dialog|
        dialog.application_name = 'Exhibit'
        dialog.version = '0.1.0'
        dialog.developer_name = 'Nokse — Ruby GTK4 port'
        dialog.website = 'https://github.com/Nokse22/Exhibit'
        dialog.license_type = Gtk::License::GPL_3_0
        dialog.comments = f3d_version
        dialog.debug_info = f3d_debug_info
        dialog.add_link('libf3d', 'https://f3d.app')
        dialog.present(app.active_window)
      end
    end

    def f3d_version
      buf = FFI::MemoryPointer.new(:char, 256)
      F3D.lib_version(buf, 256)
      buf.read_string
    end

    def f3d_debug_info
      buf = FFI::MemoryPointer.new(:char, 8192)
      F3D.lib_info(buf, 8192)
      "GTK #{Gtk::MAJOR_VERSION}.#{Gtk::MINOR_VERSION}.#{Gtk::MICRO_VERSION}\n\n#{buf.read_string}"
    end

    # Launches a saved image in the user's default viewer (the "Open" button on
    # the export-succeeded toast targets this).
    def show_image_action
      Gio::SimpleAction.new('show-image-externally', GLib::VariantType.new('s')).tap do |action|
        action.signal_connect('activate') { |_a, param| launch_external(param.get_string) }
      end
    end

    def launch_external(path)
      Gtk::FileLauncher.new(Gio::File.new_for_path(path)).launch(app.active_window, nil) { }
    end

    # Stateful string action (follow / light / dark) driving the Adwaita colour
    # scheme; the menu items target it via "app.theme::<name>". Persisted so the
    # choice survives a restart.
    def theme_action
      Gio::SimpleAction.new('theme', GLib::VariantType.new('s'), GLib::Variant.new(AppSettings.get('theme'))).tap do |action|
        action.signal_connect('change-state') do |act, state|
          key = variant_string(state)
          act.state = GLib::Variant.new(key)
          apply_theme(key)
          AppSettings.update('theme' => key)
        end
      end
    end

    def variant_string(value)
      if value.is_a?(String) then value else value.get_string end
    end

    def apply_theme(name)
      manager = Adwaita::StyleManager.default
      case name
      when 'light' then manager.color_scheme = Adwaita::ColorScheme::FORCE_LIGHT
      when 'dark' then manager.color_scheme = Adwaita::ColorScheme::FORCE_DARK
      else manager.color_scheme = Adwaita::ColorScheme::DEFAULT
      end
    end

    # Retain each MainWindow so its Ruby-side state (viewer, callbacks) outlives
    # this method; the presented Gtk window is owned by the application.
    def open_window(path)
      windows << MainWindow.new(application: app, file: path).tap { |w| w.build.present }
    end

    def windows = @windows ||= []
  end
end
