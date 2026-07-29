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
    # f3d options set so far; re-applied whenever the engine is (re)created.
    @options = { 'render.grid.enable' => true }
  end

  def build = gl_area

  # ---- options passthrough ---------------------------------------------------
  # Set any f3d option by its dotted name. Ruby values are formatted for f3d's
  # generic setAsString: true/false, numbers, and [r,g,b] colour arrays.
  def set_option(key, value)
    @options[key] = value
    @engine.then { |e| if e then apply_option(key, value) end }
    gl_area.queue_render
  end

  def apply_option(key, value) = F3D.options_set_string(@engine, key, format_option(value))

  def apply_all_options = @options.each { |k, v| apply_option(k, v) }

  def format_option(value)
    case value
    when true then 'true'
    when false then 'false'
    when Array then value.join(',')
    else value.to_s
    end
  end

  # Recenter the camera on the model's bounding box (the "home" action).
  def reset_to_bounds
    @engine.then { |e| if e then F3D.camera_reset_to_bounds(e); gl_area.queue_render end }
  end

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
      if a.respond_to?(:set_allowed_apis) then a.set_allowed_apis(Gdk::GLAPI::GL) end
      a.signal_connect('realize') { |w| on_realize(w) }
      a.signal_connect('unrealize') { |w| on_unrealize(w) }
      a.signal_connect('render') { |w, _ctx| on_render(w) }
      a.signal_connect('resize') { |_w, width, height| on_resize(width, height) }
      a.add_controller(drag_gesture)
      a.add_controller(scroll_controller)
    end
  end

  # ---- input: orbit (left-drag), pan (middle-drag), dolly (scroll) -----------
  # Mirrors Exhibit's F3DViewer.on_drag_update / on_scroll: drag offsets are
  # cumulative from drag-begin, so we diff against the previous offset each tick.

  def drag_gesture
    @drag_gesture ||= Gtk::GestureDrag.new.tap do |g|
      g.button = 0 # 0 = listen to every button, so we can tell left from middle
      g.signal_connect('drag-begin')  { @drag_prev_x = 0.0; @drag_prev_y = 0.0 }
      g.signal_connect('drag-update') { |gesture, dx, dy| on_drag(gesture.current_button, dx, dy) }
    end
  end

  def scroll_controller
    @scroll_controller ||= Gtk::EventControllerScroll.new(Gtk::EventControllerScrollFlags::VERTICAL).tap do |c|
      c.signal_connect('scroll') { |_c, _dx, dy| on_scroll(dy); true }
    end
  end

  def on_drag(button, dx, dy)
    @engine.then do |e|
      if e
        if button == 2 then pan(e, dx, dy) else orbit(e, dx, dy) end
        @drag_prev_x = dx
        @drag_prev_y = dy
        gl_area.queue_render
      end
    end
  end

  def orbit(e, dx, dy)
    F3D.camera_azimuth(e, (@drag_prev_x - dx) * 0.5)
    F3D.camera_elevation(e, -(@drag_prev_y - dy) * 0.5)
    F3D.camera_set_view_up(e, up_vector) # keep the model upright, like always_point_up
  end

  def pan(e, dx, dy)
    dist = camera_distance(e)
    F3D.camera_pan(
      e,
      (@drag_prev_x - dx) * (0.0000001 * @width + 0.001 * dist),
      -(@drag_prev_y - dy) * (0.0000001 * @height + 0.001 * dist),
      0.0
    )
  end

  def on_scroll(dy)
    @engine.then { |e| if e then F3D.camera_dolly(e, 1 - 0.1 * dy); gl_area.queue_render end }
  end

  # camera distance from the origin, used to scale pan speed (as Exhibit does)
  def camera_distance(e)
    FFI::MemoryPointer.new(:double, 3).then do |buf|
      F3D.camera_get_position(e, buf)
      buf.read_array_of_double(3).then { |p| Math.sqrt(p[0]**2 + p[1]**2 + p[2]**2) }
    end
  end

  # +Y up, as a 3-double buffer for camera_set_view_up
  def up_vector = FFI::MemoryPointer.new(:double, 3).tap { |b| b.write_array_of_double([0.0, 1.0, 0.0]) }

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
        apply_all_options
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
