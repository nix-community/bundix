require 'minitest/autorun'
require 'bundix'
require 'tmpdir'

class TestLicenses < Minitest::Test
  Spec = Struct.new(:full_name, :source)
  Source = Struct.new(:caches)

  class LicensesStub
    attr_reader :calls

    def initialize
      @calls = []
    end

    def fetch_licenses(spec, remote)
      @calls << [spec.full_name, remote]
      ["MIT"]
    end
  end

  def setup
    @dir = Dir.mktmpdir
    @cache_home = ENV['XDG_CACHE_HOME']
    ENV['XDG_CACHE_HOME'] = File.join(@dir, 'cache')
  end

  def teardown
    ENV['XDG_CACHE_HOME'] = @cache_home
    FileUtils.remove_entry(@dir)
  end

  def build_gem(dir, licenses)
    spec = Gem::Specification.new do |s|
      s.name = 'foo'
      s.version = '1.0'
      s.summary = 'foo'
      s.authors = ['bundix']
      s.files = []
      s.licenses = licenses
    end
    FileUtils.mkdir_p(dir)
    Gem::DefaultUserInteraction.use_ui(Gem::SilentUI.new) do
      Dir.chdir(dir) { Gem::Package.build(spec) }
    end
  end

  def test_fetch_licenses_from_a_remote
    build_gem(File.join(@dir, 'remote', 'gems'), ['MIT', 'Apache-2.0'])
    spec = Spec.new('foo-1.0', Source.new([]))

    licenses = nil
    _, err = capture_io do
      licenses = Bundix::Fetcher.new.fetch_licenses(spec, File.join(@dir, 'remote'))
    end

    assert_equal(['MIT', 'Apache-2.0'], licenses)
    assert_match(/^Downloading .*foo-1\.0\.gem/, err)
  end

  def test_fetch_licenses_from_the_bundler_cache
    build_gem(File.join(@dir, 'vendor'), ['Ruby'])
    spec = Spec.new('foo-1.0', Source.new([File.join(@dir, 'vendor')]))

    assert_equal(['Ruby'], Bundix::Fetcher.new.fetch_licenses(spec, nil))
  end

  def test_fetch_licenses_without_licenses
    build_gem(File.join(@dir, 'vendor'), [])
    spec = Spec.new('foo-1.0', Source.new([File.join(@dir, 'vendor')]))

    assert_equal([], Bundix::Fetcher.new.fetch_licenses(spec, nil))
  end

  def test_fetch_licenses_without_the_gem
    spec = Spec.new('foo-1.0', Source.new([]))

    licenses = :unset
    capture_io do
      licenses = Bundix::Fetcher.new.fetch_licenses(spec, File.join(@dir, 'remote'))
    end

    assert_nil(licenses)
  end

  def cached_spec(cached)
    lock = Bundler::LockfileParser.new(
      File.read(File.expand_path('data/bundler-audit/Gemfile.lock', __dir__))
    )
    spec = lock.specs.find { |s| s.name == 'thor' }
    bundix = Bundix.new({})
    bundix.fetcher = LicensesStub.new
    [bundix.find_cached_spec(spec, 'thor' => cached), bundix.fetcher.calls]
  end

  def test_a_cached_gem_without_licenses_gets_the_licenses
    cached = {
      'version' => '0.19.4',
      'source' => {'type' => 'gem', 'remotes' => ['https://rubygems.org'], 'sha256' => 'hash'}
    }

    gem, calls = cached_spec(cached)

    assert_equal({'thor' => cached.merge('licenses' => ['MIT'])}, gem)
    assert_equal([['thor-0.19.4', 'https://rubygems.org']], calls)
  end

  def test_a_cached_gem_keeps_its_licenses
    cached = {
      'version' => '0.19.4',
      'source' => {'type' => 'gem', 'remotes' => ['https://rubygems.org'], 'sha256' => 'hash'},
      'licenses' => ['Ruby']
    }

    gem, calls = cached_spec(cached)

    assert_equal({'thor' => cached}, gem)
    assert_empty(calls)
  end
end
