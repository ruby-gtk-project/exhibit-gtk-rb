# frozen_string_literal: true

# A file-picker preference row (port of Exhibit's FileRow): a button to choose a
# file, the current filename, a clear button, drag-and-drop, and a flow-box of
# quick-pick suggestions. Used for the HDRI image. Reusable via callbacks:
#   on_added.(path)  — a file was chosen / dropped / picked from suggestions
#   on_deleted.()    — the file was cleared

require 'gtk4'
require 'adwaita'

module Exhibit
  class FileRow
    def initialize(title:, patterns:, on_added:, on_deleted:)
      @title = title
      @patterns = patterns
      @on_added = on_added
      @on_deleted = on_deleted
      @suggestion_paths = {}
    end

    def build
      row.tap do |r|
        r.child = layout

        layout.tap do |b|
          b.append(header)
          b.append(suggestions_box)
        end

        header.tap do |h|
          h.append(title_label)
          h.append(filename_label)
          h.append(file_button)
          h.append(delete_button)
        end

        file_button.signal_connect('clicked') { open_dialog }
        delete_button.signal_connect('clicked') { clear }
        suggestions_box.signal_connect('child-activated') { |_b, child| pick(@suggestion_paths[child]) }

        row.add_controller(drop_target)
        drop_target.signal_connect('drop') { |_t, value, _x, _y| on_drop(value) }
      end
    end

    def add_suggestion(path)
      Gtk::FlowBoxChild.new.tap do |child|
        child.child = Gtk::Label.new(File.basename(path, '.*')).tap { |l| l.ellipsize = :end }
        child.tooltip_text = File.basename(path)
        @suggestion_paths[child] = path
        suggestions_box.append(child)
        suggestions_box.visible = true
      end
    end

    def set_filename(path)
      @filepath = path
      filename_label.text = File.basename(path)
      filename_label.visible = true
      delete_button.visible = true
    end

    def pick(path)
      path.then { |p| if p then set_filename(p); @on_added.call(p) end }
    end

    def clear
      @filepath = nil
      filename_label.visible = false
      delete_button.visible = false
      @on_deleted.call
    end

    def open_dialog
      Gtk::FileDialog.new.tap do |d|
        d.title = "Choose #{@title}"
        d.open(file_button.root, nil) { |dialog, result| pick(finished_path(dialog, result)) }
      end
    end

    def finished_path(dialog, result)
      dialog.open_finish(result)&.path
    rescue StandardError
      nil
    end

    def on_drop(value)
      value.files.first.then { |f| if f then pick(f.path) end }
      true
    end

    # ---- widgets ---------------------------------------------------------------

    def row = @row ||= Adwaita::PreferencesRow.new.tap { |r| r.activatable = false }

    def layout
      @layout ||= Gtk::Box.new(:vertical, 6).tap do |b|
        b.margin_top = 6
        b.margin_bottom = 6
        b.margin_start = 12
        b.margin_end = 12
      end
    end

    def header = @header ||= Gtk::Box.new(:horizontal, 6)

    def title_label
      @title_label ||= Gtk::Label.new(@title).tap do |l|
        l.xalign = 0
        l.hexpand = true
      end
    end

    def filename_label
      @filename_label ||= Gtk::Label.new(nil).tap do |l|
        l.ellipsize = :end
        l.visible = false
        l.add_css_class('dim-label')
      end
    end

    def file_button
      @file_button ||= Gtk::Button.new.tap do |b|
        b.icon_name = 'document-open-symbolic'
        b.tooltip_text = "Choose #{@title}"
        b.valign = :center
      end
    end

    def delete_button
      @delete_button ||= Gtk::Button.new.tap do |b|
        b.icon_name = 'edit-clear-symbolic'
        b.tooltip_text = 'Clear'
        b.valign = :center
        b.visible = false
        b.add_css_class('flat')
      end
    end

    def suggestions_box
      @suggestions_box ||= Gtk::FlowBox.new.tap do |f|
        f.selection_mode = :none
        f.max_children_per_line = 4
        f.visible = false
      end
    end

    def drop_target = @drop_target ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)
  end
end
