# frozen_string_literal: true

# The settings hub. A plain key→value store (the Python port used a
# Gio::ListStore of Setting GObjects; we don't need that) with change observers.
# Every key belongs to a category:
#   :view     — maps to an f3d option (VIEW_KEYS) and drives the render
#   :other    — behavioural (background follow, point-up, auto-reload)
#   :internal — app state (auto-best, sidebar-show)
# Observers receive (key, value, category); MainWindow forwards :view changes to
# the viewer as f3d options.

module Exhibit
  class SettingsModel
    # UI key → f3d option name. Only view keys appear here.
    VIEW_KEYS = {
      'grid' => 'render.grid.enable',
      'grid-absolute' => 'render.grid.absolute',
      'grid-color' => 'render.grid.color',
      'translucency-support' => 'render.effect.translucency_support',
      'tone-mapping' => 'render.effect.tone_mapping',
      'ambient-occlusion' => 'render.effect.ambient_occlusion',
      'anti-aliasing' => 'render.effect.antialiasing.enable',
      'hdri-ambient' => 'render.hdri.ambient',
      'light-intensity' => 'render.light.intensity',
      'show-edges' => 'render.show_edges',
      'edges-width' => 'render.line_width',
      'sprite-enabled' => 'model.point_sprites.enable',
      'sprites-type' => 'model.point_sprites.type',
      'sprites-size' => 'model.point_sprites.size',
      'point-size' => 'render.point_size',
      'model-metallic' => 'model.material.metallic',
      'model-roughness' => 'model.material.roughness',
      'model-opacity' => 'model.color.opacity',
      'model-color' => 'model.color.rgb',
      'armature-enable' => 'render.armature.enable',
      'scivis-component' => 'model.scivis.component',
      'cells' => 'model.scivis.cells',
      'scivis-enabled' => 'model.scivis.enable',
      'hdri-skybox' => 'render.background.skybox',
      'hdri-file' => 'render.hdri.file',
      'blur-background' => 'render.background.blur.enable',
      'blur-coc' => 'render.background.blur.coc',
      'bg-color' => 'render.background.color',
      'up' => 'scene.up_direction',
      'orthographic' => 'scene.camera.orthographic',
      'animation-index' => 'scene.animation.index',
      'normal-scale' => 'model.normal.scale',
      'volume' => 'model.volume.enable',
      'inverse' => 'model.volume.inverse',
    }.freeze

    OTHER_KEYS = %w[use-color point-up auto-reload].freeze
    INTERNAL_KEYS = %w[auto-best sidebar-show].freeze

    DEFAULTS = {
      'translucency-support' => true,
      'tone-mapping' => true,
      'ambient-occlusion' => false,
      'anti-aliasing' => true,
      'hdri-ambient' => false,
      'light-intensity' => 1.5,
      'show-edges' => false,
      'edges-width' => 1.0,
      'sprite-enabled' => false,
      'point-size' => 1.0,
      'sprites-type' => 'sphere',
      'sprites-size' => 1.0,
      'model-metallic' => 0.0,
      'model-roughness' => 0.3,
      'model-opacity' => 1.0,
      'armature-enable' => false,
      'scivis-component' => -1,
      'cells' => true,
      'scivis-enabled' => false,
      'model-color' => [1.0, 1.0, 1.0],
      'grid' => true,
      'grid-absolute' => false,
      'grid-color' => [0.0, 0.0, 0.0],
      'hdri-skybox' => false,
      'hdri-file' => '',
      'blur-background' => true,
      'blur-coc' => 20.0,
      'bg-color' => [1.0, 1.0, 1.0],
      'up' => '+Y',
      'orthographic' => false,
      'animation-index' => 0,
      'animation-time' => 0.0,
      'normal-scale' => 1.0,
      'volume' => false,
      'inverse' => false,
      'use-color' => false,
      'point-up' => true,
      'auto-reload' => true,
      'auto-best' => true,
      'sidebar-show' => true,
    }.freeze

    def initialize(defaults: DEFAULTS)
      @values = defaults.dup
      @observers = []
    end

    def get(key) = @values[key]

    def set(key, value)
      if @values[key] != value
        @values[key] = value
        notify(key, value)
      end
    end

    def on_change(&block) = @observers << block

    # Re-emit every setting; used once at startup to push defaults downstream.
    def sync = @values.each_key { |key| notify(key, @values[key]) }

    def view_option(key) = VIEW_KEYS[key]

    def category(key)
      if OTHER_KEYS.include?(key)
        :other
      elsif INTERNAL_KEYS.include?(key)
        :internal
      else
        :view
      end
    end

    def to_h = @values.dup

    def notify(key, value)
      @observers.each { |observer| observer.call(key, value, category(key)) }
    end
  end
end
