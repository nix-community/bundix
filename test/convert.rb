require 'minitest/autorun'
require 'bundix'
require 'digest'
require 'json'

class TestConvert < Minitest::Test
  class PrefetchStub < Bundix::Fetcher
    SPECS = {
      "sorbet-static" => {
        platform: 'java-123',
        version: "0.4.4821",
      },
    }

    def nix_prefetch_url(*args)
      format_hash(Digest::SHA256.hexdigest(args.to_s))
    end

    def nix_prefetch_git(*args)
      JSON.generate("sha256" => format_hash(Digest::SHA256.hexdigest(args.to_s)))
    end

    def fetch_local_hash(spec)
      # Force to use fetch_remote_hash
      return nil
    end

    def spec_for_dependency(remote, spec)
      opts = SPECS[spec.name]
      raise "Unexpected spec query: #{name}" unless opts

      Gem::Specification.new do |s|
        s.name = spec.name
        s.version = spec.version
        s.platform = Gem::Platform.new(opts[:platform]) if opts[:platform]
      end
    end
  end

  def with_gemset(options)
    Bundler.instance_variable_set(:@root, Pathname.new(File.expand_path("data", __dir__)))
    bundle_gemfile = ENV["BUNDLE_GEMFILE"]
    ENV["BUNDLE_GEMFILE"] = options[:gemfile]
    options = {:deps => false, :lockfile => "", :gemset => ""}.merge(options)
    converter = Bundix.new(options)
    converter.fetcher = PrefetchStub.new
    yield(converter.convert)
  ensure
    ENV["BUNDLE_GEMFILE"] = bundle_gemfile
    Bundler.reset!
  end

  def test_bundler_dep
    with_gemset(
      :gemfile => File.expand_path("data/bundler-audit/Gemfile", __dir__),
      :lockfile => File.expand_path("data/bundler-audit/Gemfile.lock", __dir__),
    ) do |gemset|
      assert_equal("0.5.0", gemset.dig("bundler-audit", :version))
      assert_equal("0.19.4", gemset.dig("thor", :version))
      refute(gemset.has_key?("sorbet-static"))
    end
  end

  def test_platform_specific_lookups
    with_gemset(
      :gemfile => File.expand_path("data/bundler-audit/Gemfile", __dir__),
      :lockfile => File.expand_path("data/bundler-audit/Gemfile.lock", __dir__),
      :platform => 'java'
    ) do |gemset|
      assert_equal("0.5.0", gemset.dig("bundler-audit", :version))
      assert_equal("0.19.4", gemset.dig("thor", :version))
      assert_equal("0.4.4821-java-unknown", gemset.dig("sorbet-static", :version))
    end
  end
end
