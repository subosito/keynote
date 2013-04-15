# encoding: UTF-8

require "fileutils"
require "thread"
require "tilt"
require "tmpdir"

module Keynote
  module Inline
    def inline(*formats)
      Array(formats).each do |format|
        define_method format do |locals = {}|
          Renderer.new(self, locals, caller(1)[0], format).render
        end
      end
    end

    class Renderer
      def initialize(presenter, locals, caller_line, format)
        @presenter = presenter
        @locals = extract_locals(locals)
        @tilt   = TiltCache.fetch(*parse_caller(caller_line), format)
      end

      def render
        @tilt.render(@presenter, @locals)
      end

      private

      def extract_locals(locals)
        return locals unless locals.is_a?(Binding)

        Hash[locals.eval("local_variables").map do |local|
          [local, locals.eval(local.to_s)]
        end]
      end

      def parse_caller(caller_line)
        file, rest = caller_line.split ":", 2
        line, _    = rest.split " ", 2

        [file.strip, line.to_i]
      end
    end

    class TiltCache
      COMMENTED_LINE = /^\s*#(.*)$/

      def self.fetch(source_file, line, format)
        instance = (Thread.current[:_keynote_tilt_cache] ||= TiltCache.new)
        instance.fetch(source_file, line, format)
      end

      def self.reset
        Thread.current[:_keynote_tilt_cache] = nil
      end

      def self.cleanup_proc(tmpdir)
        proc { FileUtils.remove_entry_secure tmpdir }
      end

      def initialize
        @tmpdir = Dir.mktmpdir("keynote")
        @cache = {}
        ObjectSpace.define_finalizer(self, self.class.cleanup_proc(@tmpdir))
      end

      def fetch(source_file, line, format)
        key = "#{source_file}:#{line}"
        tilt, mtime = @cache[key]
        new_mtime   = File.mtime(source_file).to_f

        if new_mtime != mtime
          file = write_template_file(source_file, line, format)
          tilt = ::Tilt.new(file)
          @cache[key] = [tilt, new_mtime]
        end

        tilt
      end

      private

      def write_template_file(source_file, line, format)
        filename  = "#{source_file.tr('~/ ', '_')}_#{line}.#{format}"
        full_path = "#{@tmpdir}/#{filename}"

        File.open(full_path, "w") do |file|
          file.write read_template(source_file, line)
        end

        full_path
      end

      def read_template(source_file, line)
        result = ""
        File.foreach(source_file).drop(line).each do |line|
          result << (line[COMMENTED_LINE, 1] || break)
        end
        result
      end
    end
  end
end
