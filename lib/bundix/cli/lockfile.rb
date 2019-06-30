# frozen_string_literal: true

require_relative '../gemfile'
require 'tmpdir'

class Bundix
  module CLI
    # FIXME: ideally, generating a custom Gemfile would be part of the `gemfile`
    # command, but since it requires a Gemfile to begin with, it's not clear how
    # to structure it cleanly.
    class Lockfile < Command
      include GemfileHelpers

      def initialize
        super 'lockfile', takes_commands: false

        short_desc 'Generate a Gemfile.lock from the Gemfile'

        long_desc <<~DESCRIPTION
          There are two ways to use this command:

          The default is to serve as replacement for `bundle lock` if that
          doesn't work for some reason. We make sure to execute everything in a
          pristine environment to avoid impurities as much as possible.

          The other option is to create a lockfile for a specific group of gems
          using the `--groups` flag. Groups are determined by the `group`
          sections in the Gemfile.

          This can be useful if you want to package something for `nixpkgs` or
          other deployment strategies, it also cuts down build time and closure
          size.

          Creating a group-based Gemfile.lock requires a matching Gemfile, so we
          generate both.
        DESCRIPTION

        @data = { force: false, print: false, update: false, groups: [], groupfile: 'Gemfile.groups' }

        options.on('-f', '--force', 'Replace existing files') do
          data[:force] = true
        end

        options.on('--print', 'Only print the results') do
          data[:print] = true
        end

        options.on('--update', <<~DESCRIPTION) do
          Ignore the existing lockfile, update all gems by default, or update
          list of given gems
        DESCRIPTION
          data[:update] = true
        end

        options.on('--groups=GROUP1,GROUP2', Array, <<~DESCRIPTION) do |value|
          Only generate a lockfile for certain groups.
          This will generate not only a Gemfile.lock, but also Gemfile.groups,
          which can be used by bundlerEnv to prevent bundler from complaining about conflicts.
        DESCRIPTION
          data[:groups] = value
        end

        options.on('--groupfile=FILE', <<~DESCRIPTION) do |value|
        DESCRIPTION
          data[:groupfile] = value
        end
      end

      def execute
        prepare_environment
        prepare_dependencies
        in_tempdir do |_dir|
          if groups.any?
            generate_group_files
          else
            generate_default_files
          end
        end
      end

      def generate_default_files
        copy_initial_gemfile
        run_bundle_lock
        generate_gemfile('Gemfile.lock')
        if print?
          print_results
        else
          copy_results
        end
      end

      def generate_group_files
        write_initial_gemfiles
        run_bundle_lock
        generate_gemfile('groups.lock')
        if print?
          print_results
        else
          copy_results
        end
      end

      def prepare_environment
        ENV.delete('BUNDLE_PATH')
        ENV.delete('BUNDLE_FROZEN')
        ENV.delete('BUNDLE_BIN_PATH')
        ENV['BUNDLE_GEMFILE'] = 'Gemfile'
        @original_gemfile_path = File.expand_path(gemfile)
        @original_lockfile_path = File.expand_path(lockfile)
        @original_groupfile_path = File.expand_path(groupfile)
      end

      def prepare_dependencies
        require 'bundler'
        require 'bundler/cli'
        require 'bundler/cli/lock'
        require_relative '../multi_lockfile_hack'
      end

      def copy_initial_gemfile
        FileUtils.cp(@original_gemfile_path, 'Gemfile')
      end

      def write_initial_gemfiles
        File.write('initial.gemfile', File.read(@original_gemfile_path))
        File.write('Gemfile', <<~GEMFILE)
          extend Bundler::MultiLockfileHack
          eval_gemfile 'initial.gemfile'
          groups = %i[#{groups.join(' ')}]
          generate_lockfile(groups: groups, lockfile: 'groups.lock')
        GEMFILE
      end

      # TODO: silence bundler, looks like it's unconditional output which
      # reveals our tmpdir, causing confusion at best.
      def run_bundle_lock
        Bundler.reset!
        options = { 'remove-platform' => [], 'add-platform' => platforms }
        Bundler::CLI::Lock.new(options).run
      end

      def generate_gemfile(initial)
        content = File.read(initial)
        lock = Bundler::LockfileParser.new(content)
        File.write 'Gemfile', convert_lock(lock).join("\n")
        File.write 'Gemfile.lock', content
      end

      def print_results
        Dir.glob('Gemfile*') do |file|
          puts ">>> #{file}"
          puts File.read(file)
          puts '<<<'
        end
      end

      def copy_results(*_files)
        {
          'groups.lock' => @original_groupfile_path,
          'Gemfile.lock' => @original_lockfile_path,
          'Gemfile' => @original_groupfile_path
        }.each do |from, to|
          next unless File.exist?(from)

          FileUtils.cp(from, to) # unless File.exist?(to)
        end
      end

      def platforms
        Gem.platforms.map do |platform|
          case platform
          when String
            platform
          when Gem::Platform
            "#{platform.cpu}-#{platform.os}"
          end
        end
      end

      def in_tempdir
        Dir.mktmpdir 'bundle-lock' do |dir|
          Dir.chdir(dir) { yield(dir) }
        end
      end

      def groups
        params[:groups]
      end

      def print?
        params[:print]
      end

      def groupfile
        params[:groupfile]
      end
    end
  end
end
