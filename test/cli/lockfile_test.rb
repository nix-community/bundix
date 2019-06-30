# frozen_string_literal: true

require_relative '../helper.rb'
require_relative '../../lib/bundix/cli'

class Bundix
  class CliLockfileTest < MiniTest::Test
    include TestHelpers

    def lockfile(*args)
      Bundix::CLI.parser.parse(['lockfile', *args])
    end

    def copy_data(from, to)
      FileUtils.cp(data_path(from), to)
    end

    def test_no_lockfile_yet
      with_tempdir do
        copy_data('bundler-audit/Gemfile', 'Gemfile')

        capture_io { lockfile }

        assert_equal(File.read(data_path('bundler-audit/Gemfile.lock')), File.read('Gemfile.lock'))
      end
    end
  end
end
