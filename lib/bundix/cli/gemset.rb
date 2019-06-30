# frozen_string_literal: true

class Bundix
  module CLI
    class Gemset < Command
      def initialize
        super 'gemset', takes_commands: false
        short_desc 'Generate a gemset.nix from the Gemfile'

        @data = { json: false }

        options.on('--json', 'output JSON instead of Nix') do
          data[:json] = true
        end

        options.on('--print', 'output to stdout instead of the file') do
          data[:print] = true
        end
      end

      def execute
        gemset = Bundix.new(params).convert
        content = json? ? JSON.pretty_unparse(gemset) : object2nix(gemset)

        print? ? puts(content) : write_gemset(content)
      end

      def write_gemset(content)
        Tempfile.open('gemset', encoding: 'UTF-8') do |tempfile|
          tempfile.write(content)
          tempfile.flush
          FileUtils.cp(tempfile.path, params[:gemset])
          FileUtils.chmod(0o644, params[:gemset])
        end
      end

      def object2nix(obj)
        Bundix::Nixer.serialize(obj)
      end

      def json?
        params[:json]
      end

      def print?
        params[:print]
      end
    end
  end
end
