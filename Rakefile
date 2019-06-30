# frozen_string_literal: true

task :test do
  if ENV['COVERAGE']
    FileUtils.rm_rf('coverage')

    require 'simplecov'

    SimpleCov.start do
      add_filter '/test/'
    end
  end

  Dir.glob('test/**/*_test.rb') do |file|
    require_relative file
  end
end
