# frozen_string_literal: true

require_relative '../helper.rb'
require 'tmpdir'

require_relative '../../lib/bundix/cli'

class Bundix
  class CliGemsetTest < MiniTest::Test
    include TestHelpers

    OUTPUT = {
      'bundler-audit' => {
        'dependencies' => ['thor'],
        'groups' => ['default'],
        'platforms' => [],
        'source' => {
          'remotes' => ['https://rubygems.org'],
          'sha256' => '0pm22xpn3xyymsainixnrk8v3l3xi9bzwkjkspx00cfzp84xvxbq',
          'type' => 'gem'
        },
        'version' => '0.6.1'
      },
      'thor' => {
        'groups' => ['default'],
        'platforms' => [],
        'source' => {
          'remotes' => ['https://rubygems.org'],
          'sha256' => '1yhrnp9x8qcy5vc7g438amd5j9sw83ih7c30dr6g6slgw9zj3g29',
          'type' => 'gem'
        },
        'version' => '0.20.3'
      }
    }.freeze

    def gemset(*args)
      Bundix::CLI.parser.parse(['gemset', *args])
    end

    def copy_data(from, to)
      FileUtils.cp(File.expand_path("../data/#{from}", __dir__), to)
    end

    def nix2json(file)
      JSON.parse(`nix-instantiate --json --strict --eval #{file}`)
    end

    def test_gemset_nix
      with_tempdir do
        copy_data('bundler-audit/Gemfile.lock', 'Gemfile.lock')
        copy_data('bundler-audit/Gemfile', 'Gemfile')

        gemset

        output = nix2json('gemset.nix')

        assert_equal(OUTPUT, output)
      end
    end

    def test_gemset_json
      with_tempdir do
        copy_data('bundler-audit/Gemfile.lock', 'Gemfile.lock')
        copy_data('bundler-audit/Gemfile', 'Gemfile')

        gemset '--json', '--gemset', 'gemset.json'

        output = JSON.parse(File.read('gemset.json'))

        assert_equal(OUTPUT, output)
      end
    end
  end
end
