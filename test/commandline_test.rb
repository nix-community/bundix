# frozen_string_literal: true

__END__

require 'minitest/autorun'
require 'bundix/commandline'

class CommandLineTest < Minitest::Test
  def setup
    @cli = Bundix::CommandLine.new
    @cli.options = {
      project: 'test-project',
      ruby: 'test-ruby',
      gemfile: 'test-gemfile',
      lockfile: 'test-lockfile',
      gemset: 'test-gemset'
    }
  end

  def test_shell_nix
    assert_equal(@cli.shell_nix_string, <<~SHELLNIX)
      with (import <nixpkgs> {});
      let
        env = bundlerEnv {
          name = "test-project-bundler-env";
          inherit test-ruby;
          gemfile  = ./test-gemfile;
          lockfile = ./test-lockfile;
          gemset   = ./test-gemset;
        };
      in stdenv.mkDerivation {
        name = "test-project";
        buildInputs = [ env ];
      }
    SHELLNIX
  end
end
