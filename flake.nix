{
  # Exhibit-rb — a Ruby GTK4 port of nokse22's Exhibit 3D viewer.
  #
  # The 3D rendering is done by libf3d (C++). f3d has no Ruby binding and no
  # C ABI, so we build a small extern "C" shim (shim/f3d_shim.cpp) around the
  # libf3d calls the app needs, and drive it from Ruby via the `ffi` gem.
  # The GTK UI is the `gtk4` gem, built natively here.
  #
  # devShell pattern follows ruby-gtk-project/rubycam: `inputsFrom` pulls in the
  # GTK stack's own build environments so the ruby-gnome gems can resolve every
  # Requires.private .pc, plus the low-level private deps listed explicitly.

  description = "Ruby GTK4 port of Exhibit (libf3d viewer) — dev shell + shim";

  # NOT the system's 26.05 pin: that snapshot is a mid-mass-rebuild with
  # duplicate glib/cairo builds, which makes the ruby-gnome gtk4 stack die with
  # "cannot register existing type 'cairo_font_type_t'". This coherent
  # nixos-unstable rev is the one ruby-gtk-project/rubycam uses and is proven to
  # load gtk4 cleanly on this machine.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/65179426c83bb3f6bc14898b42ea1c6f01d374b0";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      ruby = pkgs.ruby_3_4;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # Inherit the GTK stack's build environments — this is what makes the
        # gtk4 gem's strict pkg-config resolution work (rubycam's trick).
        inputsFrom = with pkgs; [ gtk4 glib cairo pango gdk-pixbuf at-spi2-core ];

        nativeBuildInputs = with pkgs; [ pkg-config git git-lfs lefthook ];
        buildInputs = with pkgs; [
          ruby bundler
          libyaml openssl libffi
          gtk4 gobject-introspection at-spi2-core
          # low-level private (.pc Requires.private) deps ruby-gnome insists on:
          expat libselinux libsepol libdatrie libdeflate lerc xz zstd libwebp
          libx11 libxext libxrender libxcb libxau libxdmcp xorgproto
          # the f3d shim links libf3d (+ vtk transitively):
          f3d vtk
        ];

        shellHook = ''
          export GEM_HOME="$HOME/.gem-${ruby.version}"
          export GEM_PATH="$GEM_HOME/ruby/${ruby.version.libDir}:$GEM_HOME"
          export PATH="$GEM_HOME/bin:$GEM_HOME/ruby/${ruby.version.libDir}/bin:$PATH"
          export BUNDLE_GEMFILE="$PWD/Gemfile"
          export BUNDLE_PATH="$GEM_HOME"
          export BUNDLE_BIN="$GEM_HOME/bin"
          echo "exhibit-rb dev shell — ruby $(ruby --version | cut -d' ' -f2)"
        '';
      };
    };
}
