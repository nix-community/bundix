require 'erb'

class Bundix
  class Nixer
    attr_reader :level, :obj

    SET_T = ERB.new(File.read(File.expand_path("../../template/nixer/set.erb", __dir__)).chomp)
    LIST_T = ERB.new(File.read(File.expand_path("../../template/nixer/list.erb", __dir__)).chomp)

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
        return SET_T.result(binding)
      when Array
        return LIST_T.result(binding)
      when String
        obj.dump
      when Symbol
        obj.to_s.dump
      when Pathname
        str = obj.to_s
        if %r{/} !~ str
          "./"+ str
        else
          str
        end
      when true, false
        obj.to_s
      else
        fail "Cannot convert to nix #{obj.inspect}"
      end
    end
  end
end
