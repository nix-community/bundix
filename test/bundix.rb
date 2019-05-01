require 'minitest/autorun'
require 'bundix'

class TestBundix < Minitest::Test
  def test_parse_gemset
    res = Bundix.new(gemset: "test/data/path with space/gemset.nix").parse_gemset
    assert_equal({"a" => 1}, res)
  end
end
