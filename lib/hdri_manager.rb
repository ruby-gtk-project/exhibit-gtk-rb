# frozen_string_literal: true

# Locates HDRI files offered as quick-pick suggestions in the HDRI file row.
# They live under $XDG_DATA_HOME/exhibit-rb/HDRIs. The project ships four
# defaults under examples/hdris, but those are Git LFS assets — until `git lfs
# pull` hydrates them they're ~130-byte pointer stubs, which real_file? rejects
# (so the suggestions list is simply empty rather than offering broken files).

require 'fileutils'

module Exhibit
  module HdriManager
    module_function

    def dir
      base = ENV['XDG_DATA_HOME'] || File.join(Dir.home, '.local', 'share')
      File.join(base, 'exhibit-rb', 'HDRIs')
    end

    def list
      FileUtils.mkdir_p(dir)
      Dir.glob(File.join(dir, '*.{hdr,exr,HDR,EXR}')).select { |f| real_file?(f) }.sort
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
