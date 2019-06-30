# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/bundix'

class TestBundix < Minitest::Test
  def test_parse_gemset
    res = Bundix.new(gemset: 'test/data/path with space/gemset.nix').parse_gemset
    assert_equal({ 'a' => 1 }, res)
  end
end
