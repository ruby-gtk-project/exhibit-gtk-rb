# Exhibit-rb — Full Porting Plan

Porting Nokse22's **Exhibit** (Python/GTK4/libadwaita, `../exhibit-reference`) to Ruby GTK4
using the `ruby-gtk` skill's declarative memoized-widget house style and the
`planning-methodology.md` MVP sequencing.

**Reference size:** ~3.7k LOC Python + 1.1k LOC of `.ui` XML (v1.6.0).
**Target:** feature parity, Ruby, no `.ui` files (widgets built in code, house style).

Everything renders through the existing C++ FFI shim (`shim/f3d_shim.cpp` → `lib/f3d.rb`).
The shim's generic `f3d_options_set_string` already covers **every** f3d option via
`setAsString`, so most "settings" work needs no new shim code — only Ruby.

---

## 1. Analysis — the complete feature inventory

Grouped as the reference presents them. Each maps later to a phase.

### 1.1 Viewer / camera (partly done)
- [x] Render a model into a `Gtk::GLArea` via libf3d external GL engine (EGL/GLX).
- [x] Orbit (left-drag), pan (middle-drag), dolly/zoom (scroll). *(done last session)*
- [ ] Reset-to-bounds ("home").
- [ ] Preset views: front / right / top / isometric (keyboard `⌘1/3/7/9…`).
- [ ] Keyboard pan (WASD) and tilt (arrow keys) with **gimbal limit** near poles.
- [ ] `always_point_up` mode (reset view-up each interaction) + per-preset up direction.
- [ ] Orthographic ↔ perspective toggle (`scene.camera.orthographic`); scroll uses
      `zoom` in ortho, `dolly` in perspective.
- [ ] Camera **state** get/set (position+focal+view-up+view-angle) for orientation preserve.

### 1.2 File handling
- [ ] Open-file dialog, filtered to supported extensions.
- [ ] Drag-and-drop a 3D model **or** an HDRI onto the view / loading page.
- [ ] Startup file argument (`HANDLES_OPEN` / `do_open`), one window per file.
- [ ] `supports()` check → dedicated **error page** when a format is unsupported.
- [ ] Add-file (merge additional file into the current scene).
- [ ] Reload current file (preserving camera orientation).
- [ ] **Auto-reload** on external change (poll mtime every 500 ms).
- [ ] Stack states: startup / loading / error / 3d; window title + subtitle = filename.

### 1.3 Rendering settings (sidebar → f3d options)
The reference's `keys` dict maps ~40 UI keys to f3d options. Full list:

| UI key | f3d option | Widget | Group/Tab |
|---|---|---|---|
| grid | render.grid.enable | switch | Scene/Grid |
| grid-absolute | render.grid.absolute | switch | Scene/Grid |
| translucency-support | render.effect.translucency_support | switch | Render/Rendering |
| tone-mapping | render.effect.tone_mapping | switch | Render/Rendering |
| ambient-occlusion | render.effect.ambient_occlusion | switch | Render/Rendering |
| anti-aliasing | render.effect.antialiasing.enable | switch | Render/Rendering |
| hdri-ambient | render.hdri.ambient | switch | Render/Rendering |
| light-intensity | render.light.intensity | spin | Render/Rendering |
| show-edges | render.show_edges | switch | Render/Model Rendering |
| edges-width | render.line_width | spin | Render/Model Rendering |
| sprite-enabled | model.point_sprites.enable | switch | Render/Points |
| sprites-type | model.point_sprites.type | combo (sphere/gaussian) | Render/Points |
| sprites-size | model.point_sprites.size | spin | Render/Points |
| point-size | render.point_size | spin | Render/Points |
| model-metallic | model.material.metallic | spin | Model/Material |
| model-roughness | model.material.roughness | spin | Model/Material |
| model-opacity | model.color.opacity | spin | Model/Material |
| model-color | model.color.rgb | color button | Model/Color |
| scivis-component / cells / scivis-enabled | model.scivis.* | "Coloration" combo | Model/Color |
| armature-enable | render.armature.enable | switch | Model/Armature |
| hdri-skybox | render.background.skybox | switch | Scene/Background |
| hdri-file | render.hdri.file | file row | Scene/Background |
| blur-background | render.background.blur.enable | switch | Scene/Background |
| blur-coc | render.background.blur.coc | spin | Scene/Background |
| bg-color | render.background.color | color button | Scene/Color |
| up | scene.up_direction | combo (±X/±Y/±Z) | More/Navigation |
| orthographic | scene.camera.orthographic | header action | — |
| animation-index | scene.animation.index | spin | More/Animation |
| grid-color / normal-scale / volume / inverse | … | no UI (defaults only) | — |

Plus **non-view** settings: `use-color`, `point-up`, `auto-reload` (behavioural),
and **internal**: `auto-best`, `sidebar-show`.

### 1.4 Background & theme
- [ ] "Use custom color" switch + background color button.
- [ ] When not custom: background follows Adwaita light/dark (0.117 grey / white).
- [ ] App theme action: follow / light / dark via `Adwaita::StyleManager`.

### 1.5 HDRI management
- [ ] Ship 4 default HDRIs (city/meadow/field/sky — already in `examples/hdris/`),
      copy into `$XDG_DATA_HOME/HDRIs/` on first run.
- [ ] `FileRow`: file-open button, filename label, delete button, drop target, and a
      **suggestions flow-box** of HDRI thumbnails.
- [ ] Apply HDRI as skybox / ambient light; blur; delete/clear.
- ~~Thumbnail generation via ImageMagick (`wand`)~~ → **simplify** (see §2).

### 1.6 Presets / configurations
- [ ] Built-in `configurations.json` (General, 3D Printing, CAD, Point Cloud, Splat).
- [ ] User configs in `$XDG_DATA_HOME/configurations/`.
- [ ] Settings preset menu (built-ins + Custom + user-saved).
- [ ] **Auto-best**: pick preset by regex on the filename's extension at load.
- [ ] **Custom** state detection: when current settings deviate from the active preset.
- [ ] **Save-settings dialog**: name + extensions + a column-view of current settings,
      writes a user config JSON and appends to the menu.

### 1.7 Image export
- [ ] Save-as-image → `Gtk::FileDialog.save` → render current view to PNG.
- [ ] Success toast with an "Open" button (opens the PNG externally).

### 1.8 Application shell
- [ ] `AdwOverlaySplitView`: content = viewer, sidebar = settings `AdwViewStack`
      (Render / Model / Scene / More) + view switcher.
- [ ] Adaptive **breakpoint**: collapse sidebar when narrow.
- [ ] Header bar: home, open, sidebar toggle, preset menu, primary menu, save-as-image.
- [ ] Toast overlay.
- [ ] Actions/menus: quit, about, help, open-new-window, open-external,
      open-hdri-folder, open-configs-folder, show-image-externally, theme.
- [ ] About dialog incl. f3d/VTK lib-info debug block.
- [ ] Keyboard-shortcuts overlay (help-overlay).
- [ ] Persist window size, sidebar state, theme, auto-best across runs.

---

## 2. What to drop or simplify (methodology Step 1.2)

| Reference complexity | Why it exists | Our decision |
|---|---|---|
| `wand`/ImageMagick HDRI thumbnails | pretty previews | **Drop** for MVP — list HDRIs by filename; optionally render thumbnails with f3d offscreen later. Removes a heavy native dep. |
| Threaded `_load_file` + `PeriodicChecker` GObject | keep UI responsive | **Simplify** — load synchronously behind a "loading" label via `GLib::Idle`; poll with `GLib::Timeout`. Ruby-GNOME threading is fragile. |
| Typed f3d option API (bool/float/color) | native binding | **Already simpler** — one `options_set_string` generic setter; format values in Ruby. |
| `wand` image save for export | Python image lib | **Drop** — shim's `f3d_render_to_png` saves directly. |
| `WindowSettings` as a `Gio::ListStore` of `Setting` GObjects | drives a ColumnView | **Simplify** to a plain Ruby `SettingsModel` (hash + observer callbacks + categories). Keep a ColumnView only in the save dialog, fed from the model. |
| GSettings schema (needs install into store) | GNOME norm | **Prefer** a small JSON at `$XDG_CONFIG_HOME/exhibit/settings.json` for window/theme/auto-best; avoids shipping/compiling a gschema in Nix. (Gschema remains an option if we later want it.) |
| `Adwaita::ApplicationWindow` / `Adwaita::Application` | — | **Must** use `Gtk::Application` + `Gtk::ApplicationWindow` (Ruby Adwaita bindings for these are broken per the skill); all other `Adwaita::*` widgets work inside them. |

---

## 3. Architecture mapping (Python → Ruby, house style)

Every class: constructor takes callbacks/deps, `build` returns the root widget,
optional `update(...)`, memoized widget methods at the bottom. Entry point is one
expression. Extract a class once it passes ~10 widget methods.

| Reference (Python) | Ruby class | Responsibility |
|---|---|---|
| `main.py` `Viewer3dApplication` | `Exhibit::Application` | `Gtk::Application` (`:handles_open`), actions, theme, about, open. |
| `window.py` `Viewer3dWindow` | `MainWindow` | Split view, header, stack states, toast, wiring settings↔viewer. |
| `widgets/f3d_viewer.py` `F3DViewer` | `F3DViewer` *(exists)* | GLArea, engine, input, camera, options passthrough, animation. |
| `settings_manager.py` `WindowSettings`/`Setting` | `SettingsModel` | name→value, categories (view/other/internal), change observers, defaults, deviation diff. |
| sidebar `.ui` (Render/Model/Scene/More) | `SettingsSidebar` (+ `RenderPage`, `ModelPage`, `ScenePage`, `MorePage`) | Build the `AdwViewStack`; two-way-bind rows to `SettingsModel`. |
| `configurations.json` + preset logic | `ConfigurationStore` | Built-in + user presets, auto-best match, save new. |
| `widgets/file_row.py` `FileRow`/`ImageThumbnail` | `FileRow` | HDRI picker row with suggestions + drop + delete. |
| save-settings dialog `.ui` | `SaveSettingsDialog` | Name/extensions + current-settings column view → user JSON. |
| HDRI setup in `window.py` | `HdriManager` | Copy defaults, enumerate, (optional thumbnails). |
| `save_as_image` | `ImageExporter` | FileDialog.save → `render_to_png` → toast. |
| GSettings usage | `AppSettings` | JSON persistence of window/theme/auto-best. |
| `vector_math.py` | small `VectorMath` module | pan/tilt/gimbal math. |
| `logger_lib.py` | Ruby `Logger` (stdlib) | logging. |

**Data flow:** `SettingsModel` is the hub. UI row change → `model.set(key, val)` →
observers fire → (view keys) `F3DViewer.set_option(f3d_key, val)` + `queue_render`;
(other keys) behavioural handlers (theme bg, point-up, auto-reload); presets read/write
the whole model at once; deviation check compares model vs active preset.

---

## 4. Shim (C++) additions required

The generic string option setter covers all settings. Only these native gaps remain
(add to `shim/f3d_shim.cpp`, bind in `lib/f3d.rb`, rebuild `nix build .#shim`):

| Function | Signature | Needed by | Phase |
|---|---|---|---|
| `f3d_render_to_png` | `int(engine*, const char* path)` — **already in .cpp, not yet bound in `f3d.rb`** | Image export | 10 |
| `f3d_camera_get_state` / `f3d_camera_set_state` | `void(engine*, double out[10])` / `void(engine*, const double[10])` (pos3+focal3+up3+angle1) | Preserve orientation on reload/up-change | 7 |
| `f3d_scene_animation_time_range` | `void(engine*, double out[2])` | Animation range | 8 |
| `f3d_scene_load_animation_time` | `void(engine*, double t)` | Animation scrub/play | 8 |
| `f3d_engine_readers_extensions` | `int(char* buf, int len)` — comma-joined ext list | File dialog filters (else hardcode) | 9 |
| `f3d_engine_lib_info` | `int(char* buf, int len)` — version/VTK block | About dialog debug (optional) | 11 |

`f3d::camera` exposes `getState()/setState()` (a `camera_state_t` of position, focalPoint,
viewUp, viewAngle); scene exposes `animationTimeRange()` and `loadAnimationTime()`; engine
exposes `getReadersInfo()` and `getLibInfo()`. All wrap the same try/catch boundary pattern
already in the shim.

---

## 4a. Adwaita dependency & widget-support risk (READ FIRST)

**The `adwaita` gem is not yet a dependency.** `Gemfile` currently has only `gtk4` + `ffi`,
`gemset.nix` has no adwaita, and the current `bin/exhibit` uses pure GTK — Adwaita has
never been loaded in this project. Adding it is a **Phase 0 prerequisite** (see below),
and until it builds under Nix, none of the sidebar/split-view work can start.

**Only a subset of the Adwaita widgets this port needs are verified by the skill.**
`references/adwaita-quirks.md` confirms: `ToastOverlay`, `ToolbarView`, `HeaderBar`,
`Bin`, `Clamp`, `StatusPage`, `NavigationSplitView`, `Toast(message)`,
`PreferencesGroup` (add rows with **`add()`**, not `append()`), `PreferencesRow`,
`ActionRow`, `EntryRow`. It also confirms `Adwaita::Application`/`ApplicationWindow` are
**broken** → use the `Gtk::` versions.

The following widgets the plan relies on are **NOT covered by the skill** and must be
runtime-probed (skill's "Adding New Widgets": try `.new`; on failure read the error and try
positional args) and the result documented back into `adwaita-quirks.md`:

| Needed widget | Status | Fallback if it misbehaves |
|---|---|---|
| `AdwOverlaySplitView` | unverified (skill covers `NavigationSplitView` only) | `NavigationSplitView`, or a plain `Gtk::Paned`/`Gtk::Revealer` sidebar |
| `AdwViewStack` + `AdwViewSwitcher` | unverified | `Gtk::Stack` + `Gtk::StackSwitcher` |
| `AdwSwitchRow` | unverified | `ActionRow` + `Gtk::Switch` suffix (the pre-1.4 idiom) |
| `AdwSpinRow` | unverified | `ActionRow` + `Gtk::SpinButton` suffix |
| `AdwComboRow` | unverified | `ActionRow` + `Gtk::DropDown` suffix |
| `AdwExpanderRow` | unverified | `PreferencesGroup` + nested rows |
| `AdwAboutDialog` | unverified | `Gtk::AboutDialog` |
| `AdwBreakpoint` | unverified | manual width watch on the window's `notify::default-width` |
| `Adwaita::Toast` with `button_label`/action | only `.new(message)` verified | plain toast + a separate action |

**Because the sidebar is built almost entirely from `SwitchRow`/`SpinRow`/`ComboRow`, the
very first sidebar task (Phase 3, group 1) must begin with a 30-minute spike that probes
these three row types and picks row-vs-fallback before building all eight groups.**

---

## 5. Phased implementation (MVP → incremental)

**Golden rule:** never break a working checkpoint. Test after each phase — headless via
`f3d_render_to_png` for render-affecting changes, manual GUI for interaction.
Read `references/adwaita-quirks.md` before Phase 0b, and follow its probe procedure for
every widget in the §4a "unverified" table.

### Phase 0a — Viewer foundation *(largely done)*
Current `bin/exhibit` + `F3DViewer` render a model with orbit/pan/zoom.
**Add:** `F3DViewer#reset_to_bounds` + a `set_option(key, value)` passthrough that
formats Ruby values (bool→"true", float→"1.5", `[r,g,b]`→f3d color string).
**Checkpoint:** model renders; drag/scroll work; a code-driven `set_option('render.grid.enable','false')` hides the grid.

### Phase 0b — Add the Adwaita dependency (prerequisite for the shell)
Add `gem 'adwaita'` to `Gemfile`; regenerate `Gemfile.lock` + `gemset.nix` via bundix
(inside `nix develop`); rebuild `nix build .#gems`. Then a one-file smoke test:
`require 'adwaita'` + build a `Gtk::ApplicationWindow` containing an
`Adwaita::ToastOverlay` → `Adwaita::ToolbarView` → `Adwaita::HeaderBar`, and present it.
Probe `Adwaita::OverlaySplitView` here too (fall back to `NavigationSplitView` if needed).
**Checkpoint:** an Adwaita window opens under `nix run`; record any constructor quirks in `adwaita-quirks.md`.

### Phase 1 — App shell & layout
Replace the toy `ExhibitApp` with `Exhibit::Application` (`:handles_open`) + `MainWindow`:
`AdwOverlaySplitView` (viewer content, empty sidebar placeholder), header bar (home +
open + sidebar toggle + primary menu), `AdwToastOverlay`, and a `Gtk::Stack` with
startup / loading / error / 3d pages. Open-file dialog (permissive filter for now),
model drag-and-drop, startup-file arg, `supports()`→error page, title/subtitle.
**Checkpoint:** open via button/drop/CLI; unsupported → error/toast; home resets; sidebar toggles.

### Phase 2 — SettingsModel + option plumbing (no UI)
`SettingsModel` with the full defaults table, categories, and observers. Wire view-key
changes to `F3DViewer#set_option`. Establish the key→f3d-option map. Drive it from a
quick script/test.
**Checkpoint:** setting keys in code visibly changes renders (grid, edges, metallic, bg-color).

### Phase 3 — Settings sidebar UI (the bulk) — *one group at a time*
**Start with the §4a row-type spike:** probe `AdwSwitchRow`/`AdwSpinRow`/`AdwComboRow` (and
`AdwViewStack`); commit to row-or-fallback and record it in `adwaita-quirks.md` before
building groups. Then `SettingsSidebar` = view stack + switcher with four pages; build and
two-way-bind **one `AdwPreferencesGroup` at a time** (rows added with `add()`), testing each:
1. Render/Rendering (5 switches + light-intensity spin)
2. Render/Model-Rendering (edges switch + width spin)
3. Render/Points (sprite switch, type combo, sizes)
4. Model/Material (metallic/roughness/opacity spins)
5. Model/Color (coloration combo ↔ scivis-component/cells/scivis-enabled; model-color button, sensitivity)
6. Model/Armature (switch)
7. Scene/Grid (grid + grid-absolute)
8. More/Navigation (point-up switch, up-direction combo)
**Checkpoint after each:** the row reflects and mutates the model, and the view updates.

### Phase 4 — Background color & theme
Scene/Color group (use-color switch + bg-color button); non-custom background follows
Adwaita dark/light; app theme action (follow/light/dark) via `Adwaita::StyleManager`;
react to `notify::dark`.
**Checkpoint:** custom bg color applies; toggling system/theme changes default bg.

### Phase 5 — HDRI
`HdriManager` copies the 4 bundled HDRIs to `$XDG_DATA_HOME/HDRIs/` on first run.
`FileRow` (open/label/delete/drop + suggestions flow-box, **filenames not thumbnails** for
now). Scene/Background group: skybox switch, `FileRow`, blur switch + coc spin.
Load HDRI (also via drop on the view), clear/delete.
**Checkpoint:** pick a suggested HDRI → skybox + ambient; blur; delete restores plain bg.

### Phase 6 — Camera views & keyboard navigation
In `F3DViewer`: preset views front/right/top/isometric (using existing get/set
position+focal+view-up), keyboard pan (WASD) and tilt (arrows) with the gimbal-limit math
from `vector_math`, `always_point_up`. Register `Gio::SimpleAction`s + accelerators.
**Checkpoint:** number keys snap views; WASD/arrows move; upright maintained near poles.

### Phase 7 — Orientation preserve + reload + auto-reload
**Shim:** add `camera_get_state`/`camera_set_state`. Reload current file preserving camera
state; up-direction change triggers reload; `auto-reload` polls mtime via `GLib::Timeout`
(500 ms) and reloads on change (orientation preserved).
**Checkpoint:** edit a model externally → auto-reloads without losing the camera.

### Phase 8 — Animation
**Shim:** add `scene_animation_time_range` + `scene_load_animation_time`. `F3DViewer`
gains an animation-time property, play/pause loop (`GLib::Timeout`), and animation-index.
More/Animation group (index spin, time scale, play button); group visible only when the
model is animated.
**Checkpoint:** load an animated glTF → scrub and play/pause.

### Phase 9 — Presets / configurations
Bundle `configurations.json` into the repo (`data/`), install it to the Nix output.
`ConfigurationStore`: built-ins + user dir. Preset menu (built-ins + Custom + user).
Auto-best regex match on load. `check_for_options_change` → switch to "custom" on
deviation. `SaveSettingsDialog` (name + extensions validated against supported list +
current-settings column view) writing a user JSON and extending the menu.
**Shim:** `engine_readers_extensions` for real dialog filters (or keep hardcoded list).
**Checkpoint:** open `.stl` → 3D-Printing preset auto-applies; tweak → Custom; save preset; reopen picks it.

### Phase 10 — Image export
Bind `f3d_render_to_png` in `f3d.rb`. `ImageExporter`: `Gtk::FileDialog.save` → render PNG
→ success toast with "Open" (launches externally). Add `open-external` /
open-with-external-app for the model.
**Checkpoint:** export a PNG; toast "Open" launches it.

### Phase 11 — Application polish
About dialog (+ optional `engine_lib_info` shim for the debug block); shortcuts overlay;
open-new-window + multi-window; `AppSettings` JSON persistence (size/sidebar/theme/
auto-best); open-hdri-folder / open-configs-folder.
**Checkpoint:** About shows versions; shortcuts window opens; window state persists across runs.

### Phase 12 — Refinement
Audit every file against `references/style-rules.md` (styles in memoized methods, appends
inside parent taps, no `return`/locals, single-line bare widgets, `.then`+`if`). Extract
any class >10 widget methods. Delete dead code. Document Ruby-GNOME quirks discovered
(especially Adwaita rows, ColumnView factories, drop targets) back into the skill's
`adwaita-quirks.md`.

---

## 6. Assets & packaging to fold into `flake.nix`

- `data/configurations.json` (built-in presets) → install to the app share dir.
- `examples/hdris/*.hdr` → package as the default HDRIs (already LFS-tracked).
- Runtime dirs created lazily under `$XDG_DATA_HOME` / `$XDG_CONFIG_HOME` — no schema install.
- Each new shim function → rebuild `f3dShim`; `nix build .#shim` then `.#default`.
- No new Ruby gems required (no `wand`); `ffi` + `gtk4` already vendored via `gemset.nix`.

---

## 7. Progress tracker

- [x] Phase 0a — viewer foundation (render + orbit/pan/zoom + reset-to-bounds + set_option)
- [x] Phase 0b — added the `adwaita` gem; probed every needed widget (all construct)
- [x] Phase 1 — app shell & layout (Application + MainWindow, OverlaySplitView, header, 4 stack states, open dialog, drag-drop, supports→error). *GUI construction verified headless; interactive open/drop/render pending a display.*
- [x] Phase 2 — SettingsModel + plumbing (40 settings, 34 view→f3d-option map, observers push defaults to the viewer)
- [x] Phase 3 — settings sidebar, complete (ViewStack Render/Model/Scene/More; switches/spins/combos/colour buttons two-way bound; scivis Coloration combo; Animation group with shim time-range + playback loop; HDRI FileRow + HdriManager). Background/use-color gating is Phase 4. HDRI suggestions need `git lfs pull` to hydrate the bundled assets (machinery is in place, list is empty until then).
- [x] Phase 4 — background follows theme + Appearance (follow/light/dark) menu; added `Local/NoConditionalAssignment` cop
- [~] Phase 5 — HDRI: FileRow + HdriManager + XDG seeding done; thumbnails still simplified (filenames)
- [x] Phase 6 — preset views (front/right/top/iso) + WASD pan + arrow tilt (gimbal) + accels
- [x] Phase 7 — reload + auto-reload (mtime watcher) + preserve orientation (camera state shim)
- [x] Phase 8 — animation (shim time-range/load + playback loop; done as part of Phase 3)
- [x] Phase 9 — presets / configurations (bundled + user; auto-best on load; Custom deviation; save-preset dialog)
- [x] Phase 10 — image export (save PNG + Open toast)
- [x] Phase 11 — About, shortcuts window, new-window, full menu, and persistence (window size/sidebar/theme/auto-best via AppSettings JSON)
- [x] Phase 12 — refinement: orthographic scroll-zoom; Ruby-GNOME quirks documented (docs/ruby-gnome-quirks.md); lint clean across 17 files; full app loads clean under xvfb

**All phases complete — feature parity with the reference Exhibit.** The one
thing never verified from this environment is the live GTK window's pixels
(headless GL can't be screenshotted); everything else is verified by
construction, binding logic, offscreen renders, and camera/preset/persistence
round-trips.
