# frozen_string_literal: true

require_relative '../shell_nix_context'

class Bundix
  module CLI
    class Init < Command
      def initialize
        super 'init', takes_commands: false
        short_desc 'Create the initial shell.nix for development'

        @data = {
          shell_nix: 'shell.nix',
          force: false,
          ruby: 'ruby',
          project: File.basename(Dir.pwd)
        }

        options.on("--shell-nix=#{data[:shell_nix]}", 'Path to the shell.nix') do |value|
          data[:shell_nix] = value
        end

        options.on('-f', '--force', 'force overwriting files') do
          data[:force] = true
        end

        options.on("--ruby=#{data[:ruby]}", 'ruby version, like "ruby_2_6"') do |value|
          data[:ruby] = value
        end

        options.on("--project=#{data[:project]}", 'name of the project') do |value|
          data[:project] = value
        end
      end

      def execute
        if File.file?(params[:shell_nix]) && !params[:force]
          warn "won't override existing shell.nix but here's what it'd look like:"
          puts shell_nix_string
        else
          File.write(params[:shell_nix], shell_nix_string)
        end
      end

      def shell_nix_string
        ERB.new(template).result(shell_nix_context.bind)
      end

      def template
        File.read(File.expand_path('../../../template/shell-nix.erb', __dir__))
      end

      def shell_nix_context
        Bundix::ShellNixContext.from_hash(params)
      end
    end
  end
end
