require 'minitest/autorun'
require 'bundix'

class TestNixer < Minitest::Test
  def test_object2nix_hash
    assert_equal("{\n  a = \"x\";\n  b = \"7\";\n}", Bundix::Nixer.new({:a => "x", :b => "7"}).serialize)
  end

  def test_object2nix_array
    assert_equal('["7" "a" "string"]',Bundix::Nixer.new(["a", "7", "string"]).serialize)
  end

  def test_object2nix_pathname
    assert_equal('./.',Bundix::Nixer.new(Pathname.new(".")).serialize)
  end

  def test_object2nix_array_of_hash
    assert_equal(
      "[{\n  a = \"x\";\n  b = \"7\";\n} {\n a = \"y\";\n c = \"8\";\n}]",
      Bundix::Nixer.new([{:a => "x", :b => "7"}, {:a => "y", :c => "8"}]).serialize
    )
  end
end
