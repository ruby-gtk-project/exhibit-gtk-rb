# frozen_string_literal: true

# Exhibit-rb — Ruby GTK4 port of nokse22's Exhibit 3D viewer.
# The application owns global actions and spawns one MainWindow per file
# (HANDLES_OPEN → the 'open' signal fires once with the files passed on argv).

require 'gtk4'
require 'adwaita'
require_relative 'main_window'

module Exhibit
  class Application
    APP_ID = 'io.github.nokse22.ExhibitRb'

    def build
      app.tap do |a|
        a.signal_connect('activate') { open_window(nil) }
        a.signal_connect('open') do |_app, files, _n, _hint|
          files.each { |file| open_window(file.path) }
        end
      end
    end

    def run(argv = ARGV) = app.run(argv)

    def app
      @app ||= Gtk::Application.new(APP_ID, :handles_open).tap do |a|
        quit = Gio::SimpleAction.new('quit')
        quit.signal_connect('activate') { a.quit }
        a.add_action(quit)
        a.set_accels_for_action('app.quit', ['<Primary>q'])
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
