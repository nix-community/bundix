require 'minitest/autorun'
require 'bundix'

class TestConvert < Minitest::Test
  class PrefetchStub
    def nix_prefetch_url(*args)
      return "nix_prefetch_url_hash"
    end

    def nix_prefetch_git(uri, revision)
      return '{"sha256": "nix_prefetch_git_hash"}'
    end

    def fetch_local_hash(spec)
      return "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03" #taken from `man nix-hash`
    end

    def fetch_remotes_hash(spec, remotes)
      return "fetch_remotes_hash_hash"
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
      :lockfile => File.expand_path("data/bundler-audit/Gemfile.lock", __dir__)
    ) do |gemset|
      assert_equal("0.5.0", gemset.dig("bundler-audit", :version))
      assert_equal("0.19.4", gemset.dig("thor", :version))
    end
  end

  # gemset.nix was written for an older Gemfile in which thor was in the test
  # group, with other platforms. The cached source must be reused, but groups
  # and platforms must follow the Gemfile.
  def test_stale_cache_is_refreshed
    data = File.expand_path("data/stale-cache", __dir__)
    with_gemset(
      :gemfile => "#{data}/Gemfile",
      :lockfile => "#{data}/Gemfile.lock",
      :gemset => "#{data}/gemset.nix"
    ) do |gemset|
      thor = gemset.fetch("thor")
      assert_equal("cached_thor_hash", thor.dig("source", "sha256"))
      assert_includes(thor[:groups], :default)
      refute_includes(thor[:groups].map(&:to_s), "test")
      assert_equal([], thor[:platforms])
      refute(thor.key?("groups") || thor.key?("platforms"), "stale string keys must be dropped")

      audit = gemset.fetch("bundler-audit")
      assert_equal("cached_bundler_audit_hash", audit.dig("source", "sha256"))
      assert_equal([:development], audit[:groups])
      assert_equal(["thor"], audit["dependencies"])
    end
  end
end
