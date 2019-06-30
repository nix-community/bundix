# frozen_string_literal: true

require 'erb'

class Hash
  # regretfully, duckpunching
  def <=>(other)
    if other.is_a?(Hash)
      larray = to_a.sort { |l, r| Bundix::Nixer.order(l, r) }
      rarray = other.to_a.sort { |l, r| Bundix::Nixer.order(l, r) }
      larray <=> rarray
    end
  end
end

class Bundix
  class Nixer
    class << self
      def serialize(obj)
        new(obj).serialize
      end

      def order(left, right)
        if right.is_a?(left.class)
          if right.respond_to?(:<=>)
            cmp = right <=> left
            return -1 * cmp unless cmp.nil?
          end
        end

        if left.is_a?(right.class)
          if left.respond_to?(:<=>)
            cmp = right <=> left
            if cmp.nil?
              return class_order(left, right)
            else
              return cmp
            end
          end
        end

        class_order(left, right)
      end

      def class_order(left, right)
        left.class.name <=> right.class.name # like Erlang
      end
    end

    attr_reader :level, :obj

    SET_T = ERB.new(File.read(File.expand_path('../../template/nixer/set.erb', __dir__)).chomp)
    LIST_T = ERB.new(File.read(File.expand_path('../../template/nixer/list.erb', __dir__)).chomp)

    def initialize(obj, level = 0)
      @obj = obj
      @level = level
    end

    def indent
      ' ' * (level + 2)
    end

    def outdent
      ' ' * level
    end

    def sub(obj, indent = 0)
      self.class.new(obj, level + indent).serialize
    end

    def serialize_key(k)
      if k.to_s =~ /^[a-zA-Z_-]+[a-zA-Z0-9_-]*$/
        k.to_s
      else
        sub(k, 2)
      end
    end

    def serialize
      case obj
      when Hash
        SET_T.result(binding)
      when Array
        LIST_T.result(binding)
      when String
        obj.dump
      when Numeric
        obj.to_s
      when Symbol
        obj.to_s.dump
      when Pathname
        str = obj.to_s
        if %r{/} !~ str
          './' + str
        else
          str
        end
      when true, false
        obj.to_s
      when nil
        'null'
      else
        raise "Cannot convert to nix: #{obj.inspect}"
      end
    end
  end
end
