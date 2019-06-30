# frozen_string_literal: true

require 'minitest/autorun'

class Bundix
  module TestHelpers
    def with_tempdir
      Dir.mktmpdir('bundix-test') do |dir|
        Dir.chdir dir do
          @dir = dir
          yield
        end
      end
    end

    def data_path(file)
      File.expand_path("data/#{file}", __dir__)
    end
  end
end
