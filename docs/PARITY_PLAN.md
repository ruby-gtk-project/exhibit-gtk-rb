# Full-parity plan — remaining gaps vs the fork

Everything functional is already ported; these are the residual UX/info touches
that separate the port from 1:1 parity with nokse22's Exhibit. Ordered by value,
with shim work grouped. Each stage is independently shippable + lint-clean.

## Stage 1 — HDRI drop on the main view  *(functional, no shim)*
The fork's view drop target accepts **images too** (`hdr exr png jpg pnm tiff bmp`)
→ loads them as the HDRI/skybox; other supported files load as models. Ours only
handles models. Route image extensions to the sidebar's `set_hdri` path.
- Files: `main_window.rb` (`on_drop`).
- Verify: dropping a `.hdr` sets `hdri-file`/`hdri-skybox`; a model still loads.

## Stage 2 — Supported-format filters + extension validation  *(shim)*
The fork builds an "All supported formats" `Gtk::FileFilter` from
`f3d.Engine.get_readers_info()` and validates the save-preset extensions against
that list. We open with no filter and don't validate.
- Shim: `f3d_engine_readers_extensions(buf, len)` → comma-joined extension list.
- Files: `f3d.rb`, `main_window.rb` (open/add dialogs), `save_preset_dialog.rb`
  (mark the extensions row `error` when unknown).
- Verify: open dialog filters to supported types; unknown ext flags the row.

## Stage 3 — Drop-zone visual feedback  *(UX)*
On drag-enter show a "Drop 3D Model or HDRI" overlay; hide on leave
(`on_drop_enter`/`on_drop_leave` in the fork).
- Files: `main_window.rb` — a `Gtk::Overlay` + `Adwaita::StatusPage` revealer, or
  a stack "drop" page toggled by `Gtk::DropControllerMotion` enter/leave.
- Verify: dragging a file over the window reveals the hint; leaving hides it.

## Stage 4 — Pinch-to-zoom  *(UX / touch)*
Two-finger pinch → dolly, matching `on_zoom_scale_changed` (touchpad/touchscreen).
- Files: `f3d_viewer.rb` — add a `Gtk::GestureZoom` controller driving
  `camera_dolly`/`camera_zoom` by the scale delta.
- Verify: pinch changes zoom; existing scroll/drag unaffected.

## Stage 5 — About debug info  *(info parity, shim)*
The fork's About dialog carries a full debug block (F3D version/build-date/VTK,
modules, rendering backends, GTK/session env). We only show the version line.
- Shim: extend to expose build date + modules + rendering-backend list
  (`engine::getLibInfo()` + `engine::getRenderingBackendList()`), e.g.
  `f3d_lib_info(buf, len)` returning a preformatted multi-line block.
- Files: `f3d_shim.cpp`, `f3d.rb`, `application.rb` (`about.debug_info=`).
- Verify: About → debug info shows f3d/VTK/modules/backends.

## Stage 6 — Sidebar live-state + in-sidebar close  *(minor UX)*
Persist the sidebar show/hide the moment it changes (not only on close), and add
a close button inside the sidebar (useful now that the breakpoint overlays it).
- Files: `settings_sidebar.rb` (header + close button emitting a callback),
  `main_window.rb` (wire close + `notify::show-sidebar` → persist).
- Verify: toggling the sidebar persists immediately; the in-sidebar × closes it.

## Stage 7 — Help  *(optional; we ship no Yelp docs)*
The fork's `app.help` opens `help:exhibit` (Yelp pages we don't have). Wire
`app.help` (F1) to open the project README/online help via `Gtk::UriLauncher`
instead, so the menu item isn't dead.
- Files: `application.rb`.
- Verify: Help opens the project URL.

## Stage 8 — HDRI thumbnails  *(optional; deliberately simplified)*
The fork renders JPEG thumbnails of HDRIs (ImageMagick) for the suggestions
flow-box; we show filenames. Optionally render thumbnails with f3d offscreen
(load HDRI as skybox, `render_to_png` small) and show them in `FileRow`.
- Files: shim (maybe), `hdri_manager.rb`, `file_row.rb`.
- Verify: suggestions show image thumbnails.

---

### Order rationale
1–2 are functional (drop + filters); 3–4 are the most visible UX; 5 is info
parity; 6 is minor; 7–8 are optional (no docs / deliberate simplification).
Stages 2 and 5 add shim functions — do them when reached, rebuilding the shim.

### Tracker
- [ ] Stage 1 — HDRI drop on main view
- [ ] Stage 2 — supported-format filters + validation
- [ ] Stage 3 — drop-zone visual feedback
- [ ] Stage 4 — pinch-to-zoom
- [ ] Stage 5 — About debug info
- [ ] Stage 6 — sidebar live-state + close button
- [ ] Stage 7 — Help (optional)
- [ ] Stage 8 — HDRI thumbnails (optional)
