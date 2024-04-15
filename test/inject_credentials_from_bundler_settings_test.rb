require 'minitest/autorun'
require 'bundix'

class Bundix
  class InjectCredentialsFromBundlerSettingsTest < MiniTest::Test
    def subject(uri)
      Bundix::Fetcher
        .new
        .inject_credentials_from_bundler_settings(uri)
    end

    def test_for_no_auth
      uri_without_auth = URI("https://foo.com/public_repo")
      with_bundler_config do |dir|
        assert_equal(uri_without_auth.to_s, subject(uri_without_auth).to_s)
      end
    end

    def test_when_auth_is_in_env_var
      token = "secret"
      ENV["BUNDLE_FOO__COM"] = token
      uri = URI("https://foo.com/private_repo")
      uri_with_auth = URI(
        "https://#{token}@foo.com/private_repo"
      )

      with_bundler_config do |dir|
        assert_equal(uri_with_auth, subject(uri))
      end
    ensure
      ENV["BUNDLE_FOO__COM"] = nil
    end

    def test_when_auth_is_in_bundler_config
      uri = URI("https://foo.com/private_repo")
      token = "secret"
      uri_with_auth = URI("https://#{token}@foo.com/private_repo")

      with_bundler_config(uri: uri, auth: token) do |dir|
        assert_equal(uri_with_auth.to_s, subject(uri).to_s)
      end
    end

    def with_bundler_config(uri: nil, auth: nil)
      Dir.mktmpdir do |dir|
        File.write("#{dir}/Gemfile", 'source "https://rubygems.org"')

        if uri && auth
          key = "BUNDLE_#{uri.host.gsub(".","__").gsub("-","___").upcase}"
          FileUtils.mkdir("#{dir}/.bundle")
          File.write("#{dir}/.bundle/config", "---\n#{key}: #{auth}\n")
        end

        Dir.chdir(dir) do
          Bundler.reset!
          yield(dir)
        end
      end
    end
  end
end
