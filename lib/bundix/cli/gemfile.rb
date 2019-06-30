# frozen_string_literal: true

require_relative '../../bundix'
require_relative '../gemfile'

class Bundix
  module CLI
    class Gemfile < Command
      include GemfileHelpers

      def initialize
        super 'gemfile', takes_commands: false
        short_desc 'Generate a Gemfile from the Gemfile.lock'

        @data = { force: false, print: false }

        options.on('-f', '--force', 'replace existing files') do
          data[:force] = true
        end

        options.on('--print', 'print the Gemfile instead') do
          data[:print] = true
        end
      end

      def execute
        if params[:print]
          puts new_gemfile
        elsif write?
          save_gemfile
        else
          warn "Will not replace existing #{gemfile}, use the `--force` flag"
        end
      end

      def save_gemfile
        Tempfile.open('Gemfile', encoding: 'UTF-8') do |tempfile|
          tempfile.puts(new_gemfile)
          tempfile.flush
          FileUtils.cp(tempfile.path, gemfile)
          FileUtils.chmod(0o644, gemfile)
        end
      end

      def new_gemfile
        @new_gemfile ||= lockfile2gemfile(File.read(lockfile))
      end

      def write?
        !File.file?(gemfile) || params[:force]
      end
    end
  end
end
