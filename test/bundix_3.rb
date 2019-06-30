# frozen_string_literal: true

__END__

require 'minitest/autorun'
require_relative '../lib/bundix/gemfile_lock'

class TestBundixCommandLine < Minitest::Test
  def test_lock
    Bundix.lock
  end
end

class TestBundixGemfile < Minitest::Test
  def test_to_gemfile_simple
    gemset = Bundix::GemfileLock.from_string <<~LOCK
      GEM
        remote: https://rubygems.org/
        specs:
          minitest (5.11.3)
      PLATFORMS
        ruby
      DEPENDENCIES
        minitest!
      BUNDLED WITH
        1.17.2
    LOCK

    assert_equal gemset.to_gemfile.join("\n") + "\n", <<~LOCK
      source "https://rubygems.org/" do
        gem "minitest", "5.11.3"
      end
    LOCK
  end

  def test_to_gemfile_mixed
    gemset = Bundix::GemfileLock.from_string <<~LOCK
      GEM
        remote: https://rubygems.org/
        specs:
          minitest (5.11.3)
      GIT
        remote: https://github.com/manveru/bundix
        revision: 9fbaa97e71c2387d912379be1aaaf1c577d059c4
        specs:
          bundix (2.4.3)
            bundler (>= 1.11)
      PLATFORMS
        ruby
      DEPENDENCIES
        minitest!
        bundix!
      BUNDLED WITH
        1.17.2
    LOCK

    assert_equal gemset.to_gemfile.join("\n") + "\n", <<~LOCK
      source "https://rubygems.org/" do
        gem "minitest", "5.11.3"
      end
      gem "bundix", git: "https://github.com/manveru/bundix"
    LOCK
  end
end
