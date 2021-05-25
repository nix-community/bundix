require 'optparse'
require 'tmpdir'
require 'tempfile'
require 'pathname'

require_relative '../bundix'
require_relative 'shell_nix_context'

class Bundix
  class CommandLine

    DEFAULT_OPTIONS = {
      ruby: 'ruby',
      bundle_pack_path: 'vendor/bundle',
      gemfile: 'Gemfile',
      lockfile: 'Gemfile.lock',
      gemset: 'gemset.nix',
      project: File.basename(Dir.pwd),
      platform: 'ruby'
    }

    def self.run
      self.new.run
    end

    def initialize
      @options = DEFAULT_OPTIONS.clone
    end

    attr_accessor :options

    def run
      parse_options
      handle_magic
      handle_lock
      handle_init
      platforms_and_paths.each do |platform, path|
        gemset = build_gemset(path, platform)
        save_gemset(gemset, path)
      end
    end

    def parse_options
      op = OptionParser.new do |o|
        o.on '-m', '--magic', 'lock, pack, and write dependencies' do
          options[:magic] = true
        end

        o.on "--ruby=#{options[:ruby]}", 'ruby version to use for magic and init, defaults to latest' do |value|
          options[:ruby] = value
        end

        o.on "--bundle-pack-path=#{options[:bundle_pack_path]}", "path to pack the magic" do |value|
          options[:bundle_pack_path] = value
        end

        o.on '-i', '--init', "initialize a new shell.nix for nix-shell (won't overwrite old ones)" do
          options[:init] = true
        end

        o.on "--gemset=#{options[:gemset]}", 'path to the gemset.nix' do |value|
          options[:gemset] = File.expand_path(value)
        end

        o.on "--lockfile=#{options[:lockfile]}", 'path to the Gemfile.lock' do |value|
          options[:lockfile] = File.expand_path(value)
        end

        o.on "--gemfile=#{options[:gemfile]}", 'path to the Gemfile' do |value|
          options[:gemfile] = File.expand_path(value)
        end

        o.on "--platform=#{options[:platform]}", 'platform version to use' do |value|
          options[:platform] = value
        end

        o.on "--platforms=ruby", 'auto-generate gemsets for multiple comma-separated platforms' do |value|
          options[:platforms] = value
        end

        o.on '-d', '--dependencies', 'include gem dependencies (deprecated)' do
          warn '--dependencies/-d is deprecated because'
          warn 'dependencies will always be fetched'
        end

        o.on '-q', '--quiet', 'only output errors' do
          options[:quiet] = true
        end

        o.on '-l', '--lock', 'generate Gemfile.lock first' do
          options[:lock] = true
        end

        o.on '-v', '--version', 'show the version of bundix' do
          puts Bundix::VERSION
          exit
        end

        o.on '--env', 'show the environment in bundix' do
          system('env')
          exit
        end
      end

      op.parse!
      $VERBOSE = !options[:quiet]
      options
    end

    def handle_magic
      ENV['BUNDLE_GEMFILE'] = options[:gemfile]

      if options[:magic]
        fail unless system(
          Bundix::NIX_SHELL, '-p', options[:ruby],
          "bundler.override { ruby = #{options[:ruby]}; }",
          "--command", "bundle lock --lockfile=#{options[:lockfile]}")
        fail unless system(
          Bundix::NIX_SHELL, '-p', options[:ruby],
          "bundler.override { ruby = #{options[:ruby]}; }",
          "--command", "bundle pack --all --path #{options[:bundle_pack_path]}")
      end
    end

    def shell_nix_context
      ShellNixContext.from_hash(options)
    end

    def shell_nix_string
      tmpl = ERB.new(File.read(File.expand_path('../../template/shell-nix.erb', __dir__)))
      tmpl.result(shell_nix_context.bind)
    end

    def handle_init
      if options[:init]
        if File.file?('shell.nix')
          warn "won't override existing shell.nix but here is what it'd look like:"
          puts shell_nix_string
        else
          File.write('shell.nix', shell_nix_string)
        end
      end
    end

    def handle_lock
      if options[:lock]
        lock = !File.file?(options[:lockfile])
        lock ||= File.mtime(options[:gemfile]) > File.mtime(options[:lockfile])
        if lock
          ENV.delete('BUNDLE_PATH')
          ENV.delete('BUNDLE_FROZEN')
          ENV.delete('BUNDLE_BIN_PATH')
          system('bundle', 'lock')
          fail 'bundle lock failed' unless $?.success?
        end
      end
    end

    def build_gemset(gemset, platform)
      Bundix.new(options.merge(gemset: gemset, platform: platform)).convert
    end

    def object2nix(obj)
      Nixer.serialize(obj)
    end

    # If options[:platforms] is set, autogenerate a list of platforms & paths like
    # [["ruby", "gemset.nix"], ["x86_64-darwin", "gemset.x86_64-darwin.nix"]]
    # Otherwise, just rely on the specific platform & path.
    def platforms_and_paths
      gemset_path = options[:gemset]
      if options[:platforms]
        platforms = options[:platforms].split(",")
        platforms.map { |p| [p, path_with_platform(gemset_path, p)] }
      else
        [[options[:platform], gemset_path]]
      end
    end

    # convert a path like "gemset.nix" to a platform-specific one like "gemset.x86_64-linux.nix"
    def path_with_platform(path, platform)
      if platform == "ruby"
        path
      else
        path_with_platform = path.sub(/\.nix$/, ".#{platform}.nix")
        fail "Couldn't add platform to path" unless Regexp.last_match
        path_with_platform
      end
    end

    def save_gemset(gemset, path)
      tempfile = Tempfile.new('gemset.nix', encoding: 'UTF-8')
      begin
        tempfile.write(object2nix(gemset))
        tempfile.write("\n")
        tempfile.flush
        FileUtils.cp(tempfile.path, path)
        FileUtils.chmod(0644, path)
      ensure
        tempfile.close!
        tempfile.unlink
      end
    end
  end
end
