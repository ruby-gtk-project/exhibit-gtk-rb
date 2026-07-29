# frozen_string_literal: true

# F3DViewer — a Gtk::GLArea that renders a 3D model with libf3d (via the FFI
# shim). Composition over subclassing per the house style: `build` returns the
# GLArea widget; f3d state lives on this object.
#
# libf3d's "external" engine renders into whatever GL context is current, which
# is exactly what GTK makes current around the GLArea realize/render signals.

require_relative 'f3d'

class F3DViewer
  def initialize(file: nil)
    @file = file
    @engine = nil
    @width = 1
    @height = 1
  end

  def build = gl_area

  def load(path)
    @file = path
    gl_area.then do |a|
      if @engine
        F3D.scene_clear(@engine)
        F3D.scene_add(@engine, path)
        F3D.camera_reset_to_bounds(@engine)
        a.queue_render
      end
    end
  end

  def gl_area
    @gl_area ||= Gtk::GLArea.new.tap do |a|
      a.hexpand = true
      a.vexpand = true
      a.auto_render = true
      # libf3d needs desktop GL, not GLES
      a.set_allowed_apis(Gdk::GLAPI::GL) if a.respond_to?(:set_allowed_apis)
      a.signal_connect('realize') { |w| on_realize(w) }
      a.signal_connect('unrealize') { |w| on_unrealize(w) }
      a.signal_connect('render') { |w, _ctx| on_render(w) }
      a.signal_connect('resize') { |_w, width, height| on_resize(width, height) }
    end
  end

  def on_realize(area)
    area.make_current
    area.error.then { |e| if e then warn("GLArea realize error: #{e.message}"); next end }

    @engine = create_engine
    @engine.null?.then do |bad|
      if bad
        warn 'f3d: failed to create external engine'
        @engine = nil
      else
        F3D.autoload_plugins
        F3D.options_set_string(@engine, 'render.grid.enable', 'true')
        @file.then { |f| if f then F3D.scene_add(@engine, f); F3D.camera_reset_to_bounds(@engine) end }
      end
    end
  end

  def on_unrealize(area)
    area.make_current
    @engine.then { |e| if e then F3D.engine_free(e); @engine = nil end }
  end

  def on_render(_area)
    @engine.then do |e|
      if e
        F3D.window_set_size(e, @width, @height)
        F3D.window_render(e)
      end
    end
    true
  end

  def on_resize(width, height)
    @width = width
    @height = height
    false
  end

  # Wayland → EGL, X11 → GLX, matching Exhibit's own backend selection.
  def create_engine
    if ENV['WAYLAND_DISPLAY']
      F3D.engine_new_egl
    else
      F3D.engine_new_glx
    end
  end
end
