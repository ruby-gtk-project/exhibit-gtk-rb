# frozen_string_literal: true

# Exhibit-rb — Ruby GTK4 port of nokse22's Exhibit 3D viewer.
# The application owns global actions and spawns one MainWindow per file
# (HANDLES_OPEN → the 'open' signal fires once with the files passed on argv).

require 'gtk4'
require 'adwaita'
require_relative 'main_window'
require_relative 'hdri_manager'

module Exhibit
  class Application
    APP_ID = 'io.github.nokse22.ExhibitRb'

    def build
      HdriManager.seed
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
      end
    end

    # Stateful string action (follow / light / dark) driving the Adwaita colour
    # scheme; the menu items target it via "app.theme::<name>".
    def theme_action
      Gio::SimpleAction.new('theme', GLib::VariantType.new('s'), GLib::Variant.new('follow')).tap do |action|
        action.signal_connect('activate') do |act, param|
          act.state = param
          apply_theme(param.get_string)
        end
      end
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
