require 'minitest/autorun'
require 'bundix'

class Bundix
  class NixPrefetchGitCommandTest < MiniTest::Test
    def subject(uri, revision, submodules)
      Bundix::Fetcher.new.nix_prefetch_git_command(uri, revision, submodules)
    end

    def test_for_public_repo
      uri = URI("https://foo.com/public_repo")
      revision = "123"
      submodules = false
      with_bundler_config do |_|
        assert_equal(
          [
            NIX_PREFETCH_GIT,
            "--url", "#{uri}",
            "--rev", "#{revision}",
            "--hash", "sha256"
          ],
          subject(
            uri, revision, submodules
          ),
        )
      end
    end

    def test_for_private_repo
      token = "secret"
      ENV["BUNDLE_FOO__COM"] = token
      uri = URI("https://foo.com/private_repo")
      uri_with_creds = URI(
        "https://#{token}@foo.com/private_repo"
      )
      revision = "123"
      submodules = false

      with_bundler_config do |_|
        assert_equal(
          [
            NIX_PREFETCH_GIT,
            "--url", "#{uri_with_creds}",
            "--rev", "#{revision}",
            "--hash", "sha256"
          ],
          subject(
            uri, revision, submodules
          ),
        )
      end
    ensure
      ENV["BUNDLE_FOO__COM"] = nil
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
