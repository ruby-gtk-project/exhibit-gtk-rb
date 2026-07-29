# frozen_string_literal: true

# FFI binding to our extern "C" shim (shim/libf3dshim.so) around libf3d.
# The shim owns an f3d::engine* (opaque :pointer here) and reaches its
# scene/window/camera internally, so every call takes the engine handle.

require 'ffi'

module F3D
  extend FFI::Library
  ffi_lib File.expand_path('../shim/libf3dshim.so', __dir__)

  # lifecycle
  attach_function :engine_new_glx, :f3d_engine_new_glx, [], :pointer
  attach_function :engine_new_egl, :f3d_engine_new_egl, [], :pointer
  attach_function :engine_new,     :f3d_engine_new, [:int], :pointer
  attach_function :engine_free,    :f3d_engine_free, [:pointer], :void
  attach_function :autoload_plugins, :f3d_autoload_plugins, [], :void
  attach_function :log_set_verbose,  :f3d_log_set_verbose, [:int, :int], :void
  attach_function :lib_version,       :f3d_lib_version, [:pointer, :int], :void

  # scene
  attach_function :scene_supports, :f3d_scene_supports, [:pointer, :string], :int
  attach_function :scene_add,      :f3d_scene_add, [:pointer, :string], :int
  attach_function :scene_clear,    :f3d_scene_clear, [:pointer], :void
  attach_function :scene_animation_time_range, :f3d_scene_animation_time_range, [:pointer, :pointer], :void
  attach_function :scene_load_animation_time,  :f3d_scene_load_animation_time, [:pointer, :double], :void

  # window / render
  attach_function :window_set_size, :f3d_window_set_size, [:pointer, :int, :int], :void
  attach_function :window_render,   :f3d_window_render, [:pointer], :int
  attach_function :render_to_png,   :f3d_render_to_png, [:pointer, :string], :int

  # options (generic string setter over the whole f3d option namespace)
  attach_function :options_set_string, :f3d_options_set_string, [:pointer, :string, :string], :void

  # camera
  attach_function :camera_reset_to_bounds, :f3d_camera_reset_to_bounds, [:pointer], :void
  attach_function :camera_dolly,     :f3d_camera_dolly, [:pointer, :double], :void
  attach_function :camera_zoom,      :f3d_camera_zoom, [:pointer, :double], :void
  attach_function :camera_pan,       :f3d_camera_pan, [:pointer, :double, :double, :double], :void
  attach_function :camera_azimuth,   :f3d_camera_azimuth, [:pointer, :double], :void
  attach_function :camera_elevation, :f3d_camera_elevation, [:pointer, :double], :void
  attach_function :camera_get_position, :f3d_camera_get_position, [:pointer, :pointer], :void
  attach_function :camera_set_position, :f3d_camera_set_position, [:pointer, :pointer], :void
  attach_function :camera_get_focal,    :f3d_camera_get_focal, [:pointer, :pointer], :void
  attach_function :camera_set_focal,    :f3d_camera_set_focal, [:pointer, :pointer], :void
  attach_function :camera_set_view_up,  :f3d_camera_set_view_up, [:pointer, :pointer], :void
end
