# frozen_string_literal: true

# F3DViewer — a Gtk::GLArea that renders a 3D model with libf3d (via the FFI
# shim). Composition over subclassing per the house style: `build` returns the
# GLArea widget; f3d state lives on this object.
#
# libf3d's "external" engine renders into whatever GL context is current, which
# is exactly what GTK makes current around the GLArea realize/render signals.

require_relative 'f3d'

class F3DViewer
  def initialize(file: nil, on_loaded: nil, on_error: nil)
    @file = file
    @on_loaded = on_loaded
    @on_error = on_error
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

  # ---- animation -------------------------------------------------------------
  # [start, end] of the loaded scene's animation; [0, 0] means not animated.
  def animation_range
    FFI::MemoryPointer.new(:double, 2).then do |buf|
      @engine.then { |e| if e then F3D.scene_animation_time_range(e, buf) end }
      buf.read_array_of_double(2)
    end
  end

  def animation_time=(time)
    @engine.then { |e| if e then F3D.scene_load_animation_time(e, time); gl_area.queue_render end }
  end

  # Re-add the current file (e.g. after changing scene.animation.index or the up
  # direction, which are read at scene-add time). load_current recenters the
  # camera, so with preserve: true we capture and restore the view around it.
  def reload(preserve: false)
    @engine.then do |e|
      if e
        saved = nil
        if preserve then saved = camera_state end
        load_current
        if saved then self.camera_state = saved end
      end
    end
  end

  def camera_state
    buf = FFI::MemoryPointer.new(:double, 10)
    @engine.then { |e| if e then F3D.camera_get_state(e, buf) end }
    buf.read_array_of_double(10)
  end

  def camera_state=(state)
    @engine.then { |e| if e then F3D.camera_set_state(e, write_state(state)); gl_area.queue_render end }
  end

  def write_state(a) = FFI::MemoryPointer.new(:double, 10).tap { |b| b.write_array_of_double(a.map(&:to_f)) }

  # Render the current view to a PNG. Needs the GLArea's context current (we're
  # called outside the render callback), so make it current first.
  def save_png(path)
    saved = false
    @engine.then do |e|
      if e
        gl_area.make_current
        saved = F3D.render_to_png(e, path) == 1
      end
    end
    saved
  end

  def load(path)
    @file = path
    @engine.then { |e| if e then load_current end }
  end

  # Add a file to the current scene without clearing it (menu: Add File to Scene).
  def add_file(path)
    @engine.then do |e|
      if e
        if F3D.scene_supports(e, path) == 1 && F3D.scene_add(e, path) == 1
          F3D.camera_reset_to_bounds(e)
          gl_area.queue_render
          @on_loaded&.call(path)
        else
          @on_error&.call(path)
        end
      end
    end
  end

  # Add @file to the scene, reporting success/failure through the callbacks.
  # Requires a live engine (created on realize), so callers ensure the GLArea
  # is mapped first.
  def load_current
    if F3D.scene_supports(@engine, @file) == 1
      F3D.scene_clear(@engine)
      if F3D.scene_add(@engine, @file) == 1
        F3D.camera_reset_to_bounds(@engine)
        gl_area.queue_render
        @on_loaded&.call(@file)
      else
        @on_error&.call(@file)
      end
    else
      @on_error&.call(@file)
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
    F3D.camera_set_view_up(e, up_buffer) # keep the model upright, like always_point_up
  end

  def pan(e, dx, dy)
    dist = distance
    F3D.camera_pan(
      e,
      (@drag_prev_x - dx) * (0.0000001 * @width + 0.001 * dist),
      -(@drag_prev_y - dy) * (0.0000001 * @height + 0.001 * dist),
      0.0
    )
  end

  def on_scroll(dy)
    @engine.then do |e|
      if e
        # Orthographic cameras have no depth to dolly through, so zoom instead.
        if @options['scene.camera.orthographic'] == true
          F3D.camera_zoom(e, 1 - 0.1 * dy)
        else
          F3D.camera_dolly(e, 1 - 0.1 * dy)
        end
        gl_area.queue_render
      end
    end
  end

  # ---- preset views + keyboard navigation ------------------------------------
  # Ported from Exhibit's front/right/top/isometric_view, pan_action and tilt.
  # The scene's up direction (scene.up_direction option) drives all of them.

  UP_VECTORS = {
    '-X' => [-1.0, 0.0, 0.0],
    '+X' => [1.0, 0.0, 0.0],
    '-Y' => [0.0, -1.0, 0.0],
    '+Y' => [0.0, 1.0, 0.0],
    '-Z' => [0.0, 0.0, -1.0],
    '+Z' => [0.0, 0.0, 1.0],
  }.freeze

  def front_view = set_view(rot1(up_vec), up_vec)
  def right_view = set_view(rot2(up_vec), up_vec)
  def top_view = set_view(up_vec, rot2(up_vec))

  def isometric_view
    set_position(vec_scale(vec_norm(vec_add(vec_add(rot1(up_vec), rot2(up_vec)), up_vec)), 1000), up_vec)
  end

  # WASD pan: move the camera in view space, scaled by distance (as Exhibit does).
  def pan_by(x, y, z)
    @engine.then do |e|
      if e
        v = distance / 40
        F3D.camera_pan(e, x * v, y * v, z * v)
        gl_area.queue_render
      end
    end
  end

  # Arrow-key tilt: pan then restore the focal point so the camera orbits it;
  # vertical tilt is clamped near the poles (gimbal limit) as Exhibit does.
  def tilt_by(dx, dy)
    @engine.then { |e| if e then apply_tilt(e, dx, dy) end }
  end

  def apply_tilt(e, dx, dy)
    if dy.zero? || tilt_allowed?(dy)
      v = distance / 40
      focal = focal_point
      F3D.camera_pan(e, dx * v, dy * v, 0.0)
      F3D.camera_set_focal(e, write_vec3(focal))
      F3D.camera_set_view_up(e, up_buffer)
      gl_area.queue_render
    end
  end

  def tilt_allowed?(dy)
    dist, dir = camera_to_focal_distance
    limit = distance / 10
    dist > limit || (dy.positive? && dir.negative?) || (dy.negative? && dir.positive?)
  end

  def camera_to_focal_distance
    mask = up_vec.map(&:abs)
    pos = position
    foc = focal_point
    pos_h = vec_mask(pos, mask)
    foc_h = vec_mask(foc, mask)
    [vec_dist(vec_sub(pos_h, pos), vec_sub(foc_h, foc)), height_sign(vec_sub(pos_h, foc_h))]
  end

  def height_sign(diff)
    sign = 1
    n = diff.find { |x| x != 0 }
    if n && n.negative? then sign = -1 end
    sign
  end

  # position = focal + offset·1000 (front/right/top); reset_to_bounds then frames it.
  def set_view(offset, view_up)
    @engine.then { |e| if e then apply_camera(e, vec_add(focal_point, vec_scale(offset, 1000)), view_up) end }
  end

  def set_position(pos, view_up)
    @engine.then { |e| if e then apply_camera(e, pos, view_up) end }
  end

  def apply_camera(e, pos, view_up)
    F3D.camera_set_position(e, write_vec3(pos))
    F3D.camera_set_view_up(e, write_vec3(view_up))
    F3D.camera_reset_to_bounds(e)
    gl_area.queue_render
  end

  # ---- small vector + camera-read helpers ------------------------------------

  def up_vec = UP_VECTORS[@options['scene.up_direction'] || '+Y']
  def up_buffer = write_vec3(up_vec)
  def rot1(u) = [u[2], u[0], u[1]]
  def rot2(u) = [u[1], u[2], u[0]]
  def vec_add(a, b) = [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
  def vec_sub(a, b) = [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
  def vec_scale(a, s) = [a[0] * s, a[1] * s, a[2] * s]
  def vec_mask(a, m) = [a[0] * m[0], a[1] * m[1], a[2] * m[2]]
  def vec_len(a) = Math.sqrt((a[0]**2) + (a[1]**2) + (a[2]**2))
  def vec_norm(a) = vec_scale(a, 1.0 / vec_len(a))
  def vec_dist(a, b) = vec_len(vec_sub(a, b))

  def write_vec3(a) = FFI::MemoryPointer.new(:double, 3).tap { |b| b.write_array_of_double(a.map(&:to_f)) }

  def read_vec3
    buf = FFI::MemoryPointer.new(:double, 3)
    yield(buf)
    buf.read_array_of_double(3)
  end

  def position = read_vec3 { |buf| F3D.camera_get_position(@engine, buf) }
  def focal_point = read_vec3 { |buf| F3D.camera_get_focal(@engine, buf) }
  def distance = vec_len(position)

  def on_realize(area)
    # Send f3d's warnings to stderr (forceStdErr) rather than its in-window
    # console, so they don't light the console badge over the model. WARN level
    # keeps the terminal quiet unless something's actually wrong.
    F3D.log_set_verbose(2, 1)
    area.make_current
    area.error.then { |e| if e then warn("GLArea realize error: #{e.message}") end }

    @engine = create_engine
    @engine.null?.then do |bad|
      if bad
        warn 'f3d: failed to create external engine'
        @engine = nil
      else
        F3D.autoload_plugins
        apply_all_options
        @file.then { |f| if f then load_current end }
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
