# frozen_string_literal: true

# Locates HDRI files offered as quick-pick suggestions in the HDRI file row.
# They live under $XDG_DATA_HOME/exhibit-rb/HDRIs. The project ships four
# defaults under examples/hdris, but those are Git LFS assets — until `git lfs
# pull` hydrates them they're ~130-byte pointer stubs, which real_file? rejects
# (so the suggestions list is simply empty rather than offering broken files).

require 'fileutils'
require_relative 'f3d'

module Exhibit
  module HdriManager
    module_function

    def dir
      base = ENV['XDG_DATA_HOME'] || File.join(Dir.home, '.local', 'share')
      File.join(base, 'exhibit-rb', 'HDRIs')
    end

    def thumbnails_dir = File.join(dir, 'thumbnails')

    def list
      FileUtils.mkdir_p(dir)
      Dir.glob(File.join(dir, '*.{hdr,exr,HDR,EXR}')).select { |f| real_file?(f) }.sort
    end

    # [hdri_path, cached_thumbnail_or_nil]. Reads only — thumbnails are rendered
    # in seed() (before GTK/GL init); rendering here would race the GLArea's GL
    # context and crash.
    def suggestions
      list.map { |hdri| [hdri, cached_thumbnail(hdri)] }
    end

    def cached_thumbnail(hdri)
      thumb = thumbnail_path(hdri)
      if File.exist?(thumb) then thumb end
    end

    def thumbnail_path(hdri) = File.join(thumbnails_dir, "#{File.basename(hdri, '.*')}.png")

    def thumbnail(hdri)
      FileUtils.mkdir_p(thumbnails_dir)
      thumb = thumbnail_path(hdri)
      if File.exist?(thumb) then thumb else render_thumbnail(hdri, thumb) end
    end

    # Render the HDRI as a skybox to a small PNG; nil if f3d/GL isn't available.
    def render_thumbnail(hdri, thumb)
      F3D.autoload_plugins
      engine = F3D.engine_new(1)
      result = nil
      unless engine.null?
        F3D.window_set_size(engine, 300, 200)
        F3D.options_set_string(engine, 'render.hdri.file', hdri)
        F3D.options_set_string(engine, 'render.background.skybox', 'true')
        if F3D.render_to_png(engine, thumb) == 1 then result = thumb end
        F3D.engine_free(engine)
      end
      result
    rescue StandardError
      nil
    end

    # Copy the bundled default HDRIs into the user dir on first run (skipping
    # pointer stubs and files already there). Bundled dir is the app's share
    # (nix) or the repo's examples/hdris (dev).
    def seed
      FileUtils.mkdir_p(dir)
      bundled_dir.then do |src|
        if src
          Dir.glob(File.join(src, '*.{hdr,exr}')).each { |f| seed_file(f) }
        end
      end
      # Pre-render thumbnails here — before any GTK window / GLArea exists — so
      # the offscreen f3d renders don't race the app's GL context.
      list.each { |hdri| thumbnail(hdri) }
    end

    def seed_file(path)
      dest = File.join(dir, File.basename(path))
      if real_file?(path) && !File.exist?(dest)
        FileUtils.cp(path, dest)
      end
    end

    def bundled_dir
      [File.expand_path('../hdris', __dir__),
       File.expand_path('../examples/hdris', __dir__)].find { |d| Dir.exist?(d) }
    end

    # A hydrated HDRI, not an LFS pointer stub (those are a few hundred bytes of
    # text beginning "version https://git-lfs...").
    def real_file?(path)
      File.size(path) > 4096
    rescue StandardError
      false
    end
  end
end
