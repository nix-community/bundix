# frozen_string_literal: true

require_relative '../helper.rb'
require_relative '../../lib/bundix/cli'

require 'tmpdir'

class Bundix
  class CliInitTest < MiniTest::Test
    include TestHelpers

    SHELLNIX = <<~SHELLNIX
      with (import <nixpkgs> {});
      let
        gems = bundlerEnv {
          name = "test-project-bundler-env";
          inherit ruby;
          gemfile  = ./Gemfile;
          lockfile = ./Gemfile.lock;
          gemset   = ./gemset.nix;
        };
      in mkShell {
        buildInputs = [ gems gems.wrappedRuby ];
      }
    SHELLNIX

    def init(*args)
      Bundix::CLI.parser.parse(['init', *args])
    end

    def test_writing
      with_tempdir do
        init

        assert_equal(SHELLNIX, File.read('shell.nix'))
      end
    end

    def test_avoid_overwriting
      with_tempdir do
        File.write('shell.nix', 'dummy')

        out, err = capture_io { init }

        assert_match(/won't override existing shell\.nix/, err)
        assert_match(/bundlerEnv/, out)
        assert_match(/dummy/, File.read('shell.nix'))
      end
    end

    def test_force_overwriting
      with_tempdir do
        File.write('shell.nix', 'dummy')

        init '--force'

        assert_match(/bundlerEnv/, File.read('shell.nix'))
      end
    end

    def test_ruby_flag
      with_tempdir do
        init '--ruby', 'ruby_2_6'

        assert_match(/ruby_2_6/, File.read('shell.nix'))
      end
    end

    def test_project_flag
      with_tempdir do
        init '--project', 'xanadu'

        assert_match(/xanadu/, File.read('shell.nix'))
      end
    end

    def test_shell_nix_flag
      with_tempdir do
        init '--shell-nix', 'foo.nix'

        assert_match(/bundlerEnv/, File.read('foo.nix'))
        refute(File.file?('shell.nix'))
      end
    end
  end
end
