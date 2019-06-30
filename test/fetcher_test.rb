# frozen_string_literal: true

# frozen_string_literal: true

require_relative 'helper'

require 'socket'
require 'tmpdir'
require 'base64'

(ENV.keys - ['PATH']).each { |key| ENV.delete(key) }

require_relative '../lib/bundix'

class Bundix
  class FetcherTest < MiniTest::Test
    def test_download_with_credentials
      with_dir(bundler_credential: 'secret') do |dir|
        with_server(returning_content: 'ok') do |port, responses|
          file = 'some-file'

          assert_equal(File.realpath(dir), Bundler.root.to_s)

          out, err = capture_io do
            Bundix::Fetcher.new.download(file, "http://127.0.0.1:#{port}/test")
          end

          response = responses.pop(true).join
          assert_includes(response, "Authorization: Basic #{Base64.encode64('secret:').chomp}")
          assert_equal(File.read(file), 'ok')
          assert_empty(out)
          assert_match(/^Downloading .* from http.*$/, err)
        end
      end
    end

    def test_download_without_credentials
      with_dir(bundler_credential: nil) do |dir|
        with_server(returning_content: 'ok') do |port, responses|
          file = 'some-file'

          assert_equal(File.realpath(dir), Bundler.root.to_s)

          out, err = capture_io do
            Bundix::Fetcher.new.download(file, "http://127.0.0.1:#{port}/test")
          end

          response = responses.pop(true).join
          refute_includes(response, 'Authorization:')
          assert_equal(File.read(file), 'ok')
          assert_empty(out)
          assert_match(/^Downloading .* from http.*$/, err)
        end
      end
    end

    private

    def with_dir(bundler_credential:)
      Dir.mktmpdir do |dir|
        File.write("#{dir}/Gemfile", 'source "https://rubygems.org"')

        if bundler_credential
          FileUtils.mkdir("#{dir}/.bundle")
          File.write("#{dir}/.bundle/config", "---\nBUNDLE_127__0__0__1: #{bundler_credential}\n")
        end

        Dir.chdir(dir) do
          Bundler.reset!
          yield(dir)
        end
      end
    end

    def with_server(returning_content:)
      queue = Queue.new

      thr = Thread.new do
        TCPServer.open('127.0.0.1', 0) do |server|
          Thread.current[:port_num] = server.addr[1]
          Thread.current[:server] = server

          conn = server.accept

          conn.write(
            "HTTP/1.1 200 OK\r\n" \
              "Content-Length: #{returning_content.length}\r\n" \
              "Content-Type: text/plain\r\n" \
              "\r\n" \
              "#{returning_content}"
          )

          lines = []
          until (line = conn.readline) == "\r\n"
            lines << line
          end
          queue << lines

          conn.close
          server.close
        end
      end

      sleep 0.001 until thr[:port_num]

      Thread.new { yield(thr[:port_num], queue) }.join
    ensure
      thr.join
    end
  end
end
