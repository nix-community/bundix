require 'cmdparse'
require_relative '../bundix'

class Bundix
  module CLI
    def self.parser
      parser = CmdParse::CommandParser.new(handle_exceptions: :no_help)
      parser.main_options.program_name = 'bundix'
      parser.main_options.version = Bundix::VERSION
      parser.main_options.banner = 'Bundix helps you build bundler dependencies with Nix'

      parser.global_options do |opt|
        parser.data = {
          lockfile: 'Gemfile.lock',
          gemfile: 'Gemfile',
          gemset: 'gemset.nix',
          quiet: false,
          verbose: false
        }

        opt.on('--verbose', 'output everything that might help with problems') do
          $VERBOSE = parser.data[:verbose] = true
        end

        opt.on('-q', '--quiet', 'Turn off non-critical output') do
          parser.data[:quiet] = true
        end

        opt.on("--lockfile=#{parser.data[:lockfile]}", 'Path to the Gemfile.lock') do |value|
          parser.data[:lockfile] = value
        end

        opt.on("--gemfile=#{parser.data[:gemfile]}", 'Path to the Gemfile') do |value|
          parser.data[:gemfile] = value
        end

        opt.on("--gemset=#{parser.data[:gemset]}", 'Path to the gemset.nix') do |value|
          parser.data[:gemset] = value
        end
      end

      parser.add_command(CmdParse::HelpCommand.new, default: true)
      parser.add_command(CmdParse::VersionCommand.new)

      require_relative 'cli/gemfile'
      parser.add_command(Bundix::CLI::Gemfile.new)

      require_relative 'cli/lockfile'
      parser.add_command(Bundix::CLI::Lockfile.new)

      require_relative 'cli/gemset'
      parser.add_command(Bundix::CLI::Gemset.new)

      require_relative 'cli/init'
      parser.add_command(Bundix::CLI::Init.new)

      parser
    end

    class Command < CmdParse::Command
      def params
        option_chain([self]).reverse.map(&:data).reduce(&:merge)
      end

      def option_chain(all)
        this = all.last
        return all unless this.respond_to?(:super_command)

        option_chain(all << this.super_command)
      end

      def lockfile
        params[:lockfile]
      end

      def gemfile
        params[:gemfile]
      end

      def gemset
        params[:gemset]
      end
    end
  end
end
