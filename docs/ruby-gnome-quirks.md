# Ruby-GNOME / Adwaita quirks found porting Exhibit

Binding behaviours that differ from the C/Vala/Python docs, discovered building
this app against ruby-gnome `gtk4`/`adwaita` 4.3.6 (GTK 4.22, libadwaita 1.9,
f3d 3.5). Fold the reusable ones into the `ruby-gtk` skill's `adwaita-quirks.md`.

## Application / windows

- **`GApplication.run` argv** — Ruby's `ARGV` omits the program name, but
  `g_application_run` treats `argv[0]` as it. Passing `ARGV` directly makes a
  file argument get eaten as argv[0], so `activate` fires instead of `open`.
  Prepend `$PROGRAM_NAME`: `app.run([$PROGRAM_NAME, *ARGV])`.

- **`App.new.build.run` foot-gun** — if `build` ends with `app.tap { … }` it
  *returns the inner `Gtk::Application`*, so `.run` calls `Gtk::Application#run`,
  not your wrapper's `run` (silently skipping the argv fix above). Use
  `App.new.tap(&:build).run(ARGV)`.

- **`Adwaita::ApplicationWindow` / `Adwaita::Application` are broken** — use the
  `Gtk::` versions (all other Adwaita widgets work inside them).

- **Double titlebar** — `Gtk::ApplicationWindow` draws its own default titlebar.
  Putting an `Adwaita::HeaderBar` inside the content (via `AdwToolbarView`)
  leaves both, looking like a window-in-a-window. Set the header as the window
  titlebar: `window.titlebar = header_bar`.

## Actions

- **Stateful action state is a `String`** — `action.state` returns a Ruby
  `String` (not a `GLib::Variant`) in some paths, and the `change-state` /
  `activate` value can arrive as either. Normalise:
  `v.is_a?(String) ? v : v.get_string`. Set it back with
  `action.state = GLib::Variant.new(str)`.

- Radio menu items target a stateful action via `"win.action::value"`; connect
  `change-state` (not `activate`) to run side effects + set the new state.

## Widgets

- **`Gtk::ShortcutsWindow.new` is broken** — raises "GtkWindow is not subtype of
  GtkShortcutsWindow" (and it's deprecated upstream). Build a custom dialog
  (a `Gtk::Window` of `Adwaita::PreferencesGroup`s + `Gtk::ShortcutLabel`).

- **Confirmed working** (beyond the skill's documented set), all with `.new` +
  setters unless noted:
  `Adwaita::OverlaySplitView` (`content=`/`sidebar=`/`sidebar_position=`),
  `ViewStack` (`add_titled(child, name, title)` → page, then `page.icon_name=`),
  `ViewSwitcher` (`stack=`, `policy=`),
  `SwitchRow`, `SpinRow.new(adjustment, climb_rate, digits)`,
  `ComboRow` (`model = Gtk::StringList.new([...])`, `selected`),
  `PreferencesPage`/`PreferencesGroup` (add rows with `add`),
  `EntryRow`, `StatusPage`, `ToolbarView` (`add_top_bar`),
  `AboutDialog` (property setters + `add_link`; `present(parent)`),
  `Toast` (`button_label=`/`action_name=`/`action_target=`),
  `Gtk::ShortcutLabel.new(accel)`,
  `Gtk::ColorDialogButton.new(Gtk::ColorDialog.new)` (`rgba` + `notify::rgba`),
  `Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)`.

- **`FileDialog`** async: `dialog.open(parent, cancellable) { |dlg, result| dlg.open_finish(result) }`
  (and `save`/`save_finish`); wrap the `*_finish` in a `rescue` — it raises on
  cancel.

## GSettings / dconf

- `Gio::Settings.new(id)` **aborts the process** (GLib assertion) if the schema
  isn't installed — guard first with
  `Gio::SettingsSchemaSource.default.lookup(id, true)` (returns nil if missing)
  and fall back, so a source checkout without the compiled schema doesn't crash.
- Typed access: `get_int`/`set_int`, `get_boolean`/`set_boolean`,
  `get_string`/`set_string`.
- In Nix: install the `.gschema.xml` to `$out/share/glib-2.0/schemas` and run
  `glib-compile-schemas` (needs `glib` in `nativeBuildInputs`). The **glib setup
  hook relocates** it to `$out/share/gsettings-schemas/<name>/glib-2.0/schemas`
  and sets `GSETTINGS_SCHEMA_DIR`; `wrapGAppsHook4` puts it on the wrapper's
  `XDG_DATA_DIRS`, so the app finds it at runtime. The dconf GIO module (already
  pulled in by `wrapGAppsHook4`) is the write backend.

## Build / tooling

- **Nix flakes only see git-tracked files** — a newly created `lib/*.rb` is
  invisible to `nix build` until `git add`ed (even with a dirty tree).

- **git-lfs must be on `PATH`** for its hooks/smudge filter; it lives in the dev
  shell, so run git inside `nix develop` / with direnv active, or checkouts
  leave pointer stubs and commits/`git restore` error.

- **wrapGAppsHook4** populates `gappsWrapperArgs` (`GI_TYPELIB_PATH`, pixbuf
  loaders, gsettings) in a *preFixup* hook — build a manual wrapper in
  `postFixup`, not `installPhase`, or it captures a half-filled array.

- **rubocop/lefthook**: append (don't prepend) the gem bin dir to `PATH` in the
  dev shell so nix-provided CLIs win over global gem stubs, and run rubocop with
  `env -u GEM_HOME -u GEM_PATH -u BUNDLE_GEMFILE` so a stray gemset can't crash it.

## f3d

- Route f3d's log to stderr (`setVerboseLevel(level, forceStdErr=true)`) so
  warnings don't light the in-window console badge over the model.
- `render.effect.translucency_support` is deprecated in f3d 3.5 →
  `render.effect.blending.enable`.
