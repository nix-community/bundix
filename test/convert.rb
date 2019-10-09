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
      assert_equal("0.4.4821-universal-darwin-14", gemset.dig("sorbet-static", :version))
    end
  end
end
