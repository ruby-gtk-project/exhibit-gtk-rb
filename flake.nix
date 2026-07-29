{
  # Exhibit-gtk-rb — a Ruby GTK4 port of nokse22's Exhibit 3D viewer.
  #
  # 3D rendering is libf3d (C++). f3d has no Ruby binding and no C ABI, so a
  # small extern "C" shim (shim/f3d_shim.cpp) wraps the libf3d calls we need and
  # Ruby drives it via the `ffi` gem. The GTK UI is the ruby-gnome `gtk4` gem.
  #
  #   nix run .            → build the shim + gem stack and launch the viewer
  #   nix run . -- FILE    → open FILE
  #   nix develop          → dev shell (bundle install into ./vendor)

  description = "Ruby GTK4 port of Exhibit — a libf3d 3D model viewer via a C++ FFI shim";

  # Coherent nixos-unstable rev (rubycam's): the ruby-gnome gtk4 stack loads
  # cleanly here. (The distro's 26.05 snapshot has duplicate glib/cairo builds
  # that make gtk4 die with "cannot register existing type cairo_font_type_t".)
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/65179426c83bb3f6bc14898b42ea1c6f01d374b0";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;
      ruby = pkgs.ruby_3_4;

      # ---- the extern "C" shim around libf3d --------------------------------
      f3dShim = pkgs.stdenv.mkDerivation {
        pname = "f3d-shim";
        version = "0.1.0";
        src = ./shim;
        nativeBuildInputs = [ pkgs.gcc ];
        buildInputs = [ pkgs.f3d ];
        buildPhase = ''
          g++ -std=c++17 -shared -fPIC -O2 -I vendor/f3d f3d_shim.cpp \
            -o libf3dshim.so \
            -L${pkgs.f3d}/lib -lf3d -Wl,-rpath,${pkgs.f3d}/lib
        '';
        installPhase = "install -Dm755 libf3dshim.so $out/lib/libf3dshim.so";
      };

      # ---- the native ruby-gnome gem stack ----------------------------------
      # gtk4/gdk4/gsk4 aren't in nixpkgs' defaultGemConfig; add them by mirroring
      # the gtk3/gdk3 blocks (the low-level list satisfies the ruby pkg-config
      # gem's strict Requires.private resolution).
      gtkPcDeps = with pkgs; [
        gobject-introspection gtk4 gdk-pixbuf cairo pango graphene harfbuzz
        fribidi libdeflate xz libwebp zstd lerc libdatrie libsysprof-capture
        libthai pcre2 libxdmcp libxkbcommon expat
      ];
      gems = pkgs.bundlerEnv {
        name = "exhibit-gtk-rb-gems";
        inherit ruby;
        gemdir = ./.;
        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = attrs: {
            nativeBuildInputs = [ pkgs.pkg-config ];
            propagatedBuildInputs = with pkgs; [ gobject-introspection gtk4 gdk-pixbuf cairo ];
          };
          gsk4 = attrs: {
            nativeBuildInputs = [ pkgs.pkg-config ];
            propagatedBuildInputs = with pkgs; [ gobject-introspection gtk4 graphene cairo ];
          };
          gtk4 = attrs: {
            nativeBuildInputs = [ pkgs.pkg-config pkgs.binutils ];
            buildInputs = with pkgs; [ util-linux libselinux libsepol ];
            propagatedBuildInputs = gtkPcDeps;
          };
          adwaita = attrs: {
            nativeBuildInputs = [ pkgs.pkg-config ];
            propagatedBuildInputs = with pkgs; [ libadwaita gtk4 ];
          };
        };
      };

      # ---- the wrapped application ------------------------------------------
      exhibit = pkgs.stdenv.mkDerivation {
        pname = "exhibit-gtk-rb";
        version = "0.1.0";
        src = ./.;
        # gobject-introspection's setup hook only accumulates GI_TYPELIB_PATH
        # (into gappsWrapperArgs) when it runs as a nativeBuildInput; there it
        # scans the buildInputs below for lib/girepository-1.0 typelibs.
        nativeBuildInputs = [ pkgs.wrapGAppsHook4 pkgs.makeWrapper pkgs.gobject-introspection ];
        # typelibs / schemas / pixbuf loaders wrapGAppsHook4 must collect:
        buildInputs = with pkgs; [
          gtk4 libadwaita gdk-pixbuf pango graphene harfbuzz librsvg gobject-introspection glib
          adwaita-icon-theme hicolor-icon-theme
        ];
        dontWrapGApps = true; # we wrap the ruby interpreter ourselves, below

        installPhase = ''
          runHook preInstall
          mkdir -p $out/share/exhibit
          cp -r bin lib $out/share/exhibit/
          install -Dm755 ${f3dShim}/lib/libf3dshim.so $out/share/exhibit/shim/libf3dshim.so
          # Default HDRIs (Git LFS assets) — HdriManager seeds these into
          # $XDG_DATA_HOME on first run. If the tree wasn't `git lfs pull`ed they
          # are pointer stubs and HdriManager skips them.
          mkdir -p $out/share/exhibit/hdris
          cp examples/hdris/*.hdr $out/share/exhibit/hdris/ 2>/dev/null || true
          # Built-in render presets (ConfigurationStore reads this + the user dir).
          mkdir -p $out/share/exhibit/data
          cp data/configurations.json $out/share/exhibit/data/
          runHook postInstall
        '';
        # wrapGAppsHook4 assembles gappsWrapperArgs (GI_TYPELIB_PATH, the pixbuf
        # loader cache, gsettings schemas) in a preFixup hook — which runs AFTER
        # installPhase. So build the ruby wrapper here in postFixup, once those
        # args exist; wrapping during installPhase would capture only the early
        # GIO_EXTRA_MODULES entry and miss the typelibs (→ TypelibNotFound).
        postFixup = ''
          makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/exhibit \
            "''${gappsWrapperArgs[@]}" \
            --add-flags "$out/share/exhibit/bin/exhibit"
        '';
        meta = {
          description = "Ruby GTK4 port of Exhibit — a libf3d 3D model viewer";
          mainProgram = "exhibit";
          platforms = [ system ];
        };
      };
    in
    {
      packages.${system} = {
        default = exhibit;
        exhibit = exhibit;
        shim = f3dShim;
        gems = gems;
      };

      apps.${system}.default = {
        type = "app";
        program = lib.getExe exhibit;
      };

      devShells.${system}.default = pkgs.mkShell {
        # rubycam's inputsFrom trick: pull in the GTK stack's build environments
        # so the gtk4 gem's strict pkg-config resolution works in `bundle install`.
        inputsFrom = with pkgs; [ gtk4 glib cairo pango gdk-pixbuf at-spi2-core ];
        nativeBuildInputs = with pkgs; [ pkg-config git git-lfs lefthook rubocop ];
        buildInputs = with pkgs; [
          ruby bundler libyaml openssl libffi
          gtk4 gobject-introspection at-spi2-core
          expat libselinux libsepol libdatrie libdeflate lerc xz zstd libwebp
          libx11 libxext libxrender libxcb libxau libxdmcp xorgproto
          f3d vtk
        ];
        shellHook = ''
          export GEM_HOME="$HOME/.gem-${ruby.version}"
          export GEM_PATH="$GEM_HOME/ruby/${ruby.version.libDir}:$GEM_HOME"
          # Append (not prepend) the gem bin dirs so nix-provided CLIs
          # (rubocop, lefthook, bundler) win over any globally-installed gem
          # stubs — those stubs auto-activate BUNDLE_GEMFILE and crash on gems
          # only present in the nix bundlerEnv (e.g. adwaita).
          export PATH="$PATH:$GEM_HOME/bin:$GEM_HOME/ruby/${ruby.version.libDir}/bin"
          export BUNDLE_GEMFILE="$PWD/Gemfile"
          export BUNDLE_PATH="$GEM_HOME"
          export BUNDLE_BIN="$GEM_HOME/bin"
          echo "exhibit-rb dev shell — ruby $(ruby --version | cut -d' ' -f2)"
        '';
      };
    };
}
