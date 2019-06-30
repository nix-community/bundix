# frozen_string_literal: true

require_relative '../helper.rb'
require 'tmpdir'

require_relative '../../lib/bundix/cli'

class Bundix
  class CliGemfileTest < MiniTest::Test
    include TestHelpers

    def gemfile(*args)
      Bundix::CLI.parser.parse(['gemfile', *args])
    end

    def copy_data(from, to)
      FileUtils.cp(File.expand_path("../data/#{from}", __dir__), to)
    end

    def nix2json(file)
      JSON.parse(`nix-instantiate --json --strict --eval #{file}`)
    end

    def test_printing
      with_tempdir do
        copy_data('bundler-audit/Gemfile.lock', 'Gemfile.lock')

        out, err = capture_io do
          gemfile '--print'
        end

        assert_equal(<<~GEMFILE, out)
          # frozen_string_literal: true

          source 'https://rubygems.org/' do
            gem 'bundler-audit', '= 0.6.1'
          end
        GEMFILE
        assert_equal('', err)
      end
    end

    def test_writing
      with_tempdir do
        copy_data('bundler-audit/Gemfile.lock', 'Gemfile.lock')

        out, err = capture_io do
          gemfile
        end

        assert_equal('', out)
        assert_equal('', err)

        assert_equal(<<~GEMFILE, File.read('Gemfile'))
          # frozen_string_literal: true

          source 'https://rubygems.org/' do
            gem 'bundler-audit', '= 0.6.1'
          end
        GEMFILE
      end
    end

    def test_writing_force
      with_tempdir do
        copy_data('bundler-audit/Gemfile.lock', 'Gemfile.lock')
        FileUtils.touch('Gemfile')

        out, err = capture_io do
          gemfile
        end

        assert_equal('', out)
        assert_equal(<<~ERROR, err)
          Will not replace existing Gemfile, use the `--force` flag
        ERROR

        assert_equal('', File.read('Gemfile'))

        out, err = capture_io do
          gemfile '--force'
        end

        assert_equal('', out)
        assert_equal('', err)

        assert_equal(<<~GEMFILE, File.read('Gemfile'))
          # frozen_string_literal: true

          source 'https://rubygems.org/' do
            gem 'bundler-audit', '= 0.6.1'
          end
        GEMFILE
      end
    end
  end
end
