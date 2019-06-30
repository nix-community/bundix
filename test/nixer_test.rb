# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/bundix'

class TestNixer < Minitest::Test
  def serialize(obj)
    Bundix::Nixer.new(obj).serialize
  end

  def test_serialize_hash
    assert_equal(<<~NIX.strip, serialize(a: 'x', b: '7', c: { d: 8 }))
      {
        a = "x";
        b = "7";
        c = {
          d = 8;
        };
      }
    NIX
    assert_equal("{\n  a = \"x\";\n  b = \"7\";\n}", serialize(a: 'x', b: '7'))
  end

  def test_serialize_array
    assert_equal('["7" "a" "string"]', serialize(%w[a 7 string]))
  end

  def test_serialize_pathname
    assert_equal('/absolute', serialize(Pathname.new('/absolute')))
    assert_equal('./relative', serialize(Pathname.new('./relative')))
    assert_equal('./no_slash', serialize(Pathname.new('no_slash')))
    assert_equal('./.', serialize(Pathname.new('.')))
    assert_equal('./', serialize(Pathname.new('')))
  end

  def test_serialize_array_of_hash
    assert_equal(
      "[{\n  a = \"x\";\n  b = \"7\";\n} {\n  a = \"y\";\n  c = \"8\";\n}]",
      serialize([{ a: 'x', b: '7' }, { a: 'y', c: '8' }])
    )
  end

  def test_serialize_nil
    assert_equal("null", serialize(nil))
  end

  def test_serialize_nil
    assert_equal("null", serialize(nil))
  end

  def test_serialize_bool
    assert_equal("true", serialize(true))
    assert_equal("false", serialize(false))
  end
end
