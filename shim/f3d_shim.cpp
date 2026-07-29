// f3d_shim.cpp — a thin extern "C" wrapper around the libf3d C++ API.
//
// libf3d exposes only a C++ (mangled) API and pybind11 Python bindings — no C
// ABI. This shim exports the handful of calls Exhibit needs as flat C
// functions so Ruby can drive them via the `ffi` gem. It is compiled against
// f3d's vendored public headers (shim/vendor/f3d) and linked to libf3d.so.
//
// The engine owns the scene/window/camera; we keep one engine per viewer and
// reach the sub-objects through it on each call. All C++ exceptions are caught
// at the boundary (f3d throws on load failure etc.) and mapped to return codes.

#include "engine.h"
#include "scene.h"
#include "window.h"
#include "camera.h"
#include "options.h"
#include "log.h"
#include "types.h"
#include "image.h"

#include <cstring>
#include <new>

using f3d::engine;

extern "C" {

// ---- lifecycle --------------------------------------------------------------

// Create an engine bound to the *current* external GL context (the one GTK's
// GLArea makes current during its realize/render). GLX vs EGL per display server.
engine* f3d_engine_new_glx() {
  try { return new engine(engine::createExternalGLX()); }
  catch (...) { return nullptr; }
}

engine* f3d_engine_new_egl() {
  try { return new engine(engine::createExternalEGL()); }
  catch (...) { return nullptr; }
}

engine* f3d_engine_new(int offscreen) {
  try { return new engine(engine::create(offscreen != 0)); }
  catch (...) { return nullptr; }
}

void f3d_engine_free(engine* e) { delete e; }

// The "native" plugin (and any static plugins) must be loaded before adding
// files. Static across all engines.
void f3d_autoload_plugins() {
  try { engine::autoloadPlugins(); } catch (...) {}
}

// Route f3d's log to stderr instead of its in-window console. level is a
// f3d::log::VerboseLevel (0=DEBUG..4=QUIET); force_stderr!=0 sends everything,
// including debug/info, to stderr so we can capture warnings from the embedded
// engine (which otherwise only surface via f3d's console badge).
void f3d_log_set_verbose(int level, int force_stderr) {
  try {
    f3d::log::setVerboseLevel(static_cast<f3d::log::VerboseLevel>(level), force_stderr != 0);
  } catch (...) {}
}

// ---- scene ------------------------------------------------------------------

int f3d_scene_supports(engine* e, const char* path) {
  try { return e->getScene().supports(path) ? 1 : 0; }
  catch (...) { return 0; }
}

// returns 1 on success, 0 on failure (f3d throws load_failure_exception)
int f3d_scene_add(engine* e, const char* path) {
  try { e->getScene().add(std::string(path)); return 1; }
  catch (...) { return 0; }
}

void f3d_scene_clear(engine* e) {
  try { e->getScene().clear(); } catch (...) {}
}

// ---- animation --------------------------------------------------------------

// out[0]=start, out[1]=end. Equal (0,0) means the scene has no animation.
void f3d_scene_animation_time_range(engine* e, double out[2]) {
  try { auto r = e->getScene().animationTimeRange(); out[0] = r.first; out[1] = r.second; }
  catch (...) { out[0] = 0.0; out[1] = 0.0; }
}

void f3d_scene_load_animation_time(engine* e, double t) {
  try { e->getScene().loadAnimationTime(t); } catch (...) {}
}

// ---- window / render --------------------------------------------------------

void f3d_window_set_size(engine* e, int w, int h) {
  try { e->getWindow().setSize(w, h); } catch (...) {}
}

int f3d_window_render(engine* e) {
  try { return e->getWindow().render() ? 1 : 0; }
  catch (...) { return 0; }
}

// Offscreen render straight to a PNG file (used for headless/testing proof).
int f3d_render_to_png(engine* e, const char* path) {
  try { e->getWindow().renderToImage(false).save(path); return 1; }
  catch (...) { return 0; }
}

// ---- options ----------------------------------------------------------------

// Generic string setter — covers the whole f3d option namespace
// (e.g. "render.grid.enable" = "true", "scene.up_direction" = "+Y").
void f3d_options_set_string(engine* e, const char* name, const char* value) {
  try { e->getOptions().setAsString(name, value); } catch (...) {}
}

// ---- camera -----------------------------------------------------------------

void f3d_camera_reset_to_bounds(engine* e) {
  try { e->getWindow().getCamera().resetToBounds(); } catch (...) {}
}

void f3d_camera_dolly(engine* e, double v) {
  try { e->getWindow().getCamera().dolly(v); } catch (...) {}
}
void f3d_camera_zoom(engine* e, double v) {
  try { e->getWindow().getCamera().zoom(v); } catch (...) {}
}
void f3d_camera_pan(engine* e, double right, double up, double forward) {
  try { e->getWindow().getCamera().pan(right, up, forward); } catch (...) {}
}
void f3d_camera_azimuth(engine* e, double deg) {
  try { e->getWindow().getCamera().azimuth(deg); } catch (...) {}
}
void f3d_camera_elevation(engine* e, double deg) {
  try { e->getWindow().getCamera().elevation(deg); } catch (...) {}
}

void f3d_camera_get_position(engine* e, double out[3]) {
  try { auto p = e->getWindow().getCamera().getPosition();
        out[0] = p[0]; out[1] = p[1]; out[2] = p[2]; }
  catch (...) { out[0] = out[1] = out[2] = 0.0; }
}
void f3d_camera_set_position(engine* e, const double p[3]) {
  try { e->getWindow().getCamera().setPosition(f3d::point3_t{ p[0], p[1], p[2] }); }
  catch (...) {}
}
void f3d_camera_get_focal(engine* e, double out[3]) {
  try { auto p = e->getWindow().getCamera().getFocalPoint();
        out[0] = p[0]; out[1] = p[1]; out[2] = p[2]; }
  catch (...) { out[0] = out[1] = out[2] = 0.0; }
}
void f3d_camera_set_focal(engine* e, const double p[3]) {
  try { e->getWindow().getCamera().setFocalPoint(f3d::point3_t{ p[0], p[1], p[2] }); }
  catch (...) {}
}
void f3d_camera_set_view_up(engine* e, const double u[3]) {
  try { e->getWindow().getCamera().setViewUp(f3d::vector3_t{ u[0], u[1], u[2] }); }
  catch (...) {}
}

} // extern "C"
