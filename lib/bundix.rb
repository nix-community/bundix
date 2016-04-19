require 'bundler'
require 'json'
require 'open3'
require 'set'

require_relative 'bundix/version'
require_relative 'bundix/source'
require_relative 'bundix/gemfile_dependency_tree'

class Bundix
  NIX_INSTANTIATE = 'nix-instantiate'
  NIX_PREFETCH_URL = 'nix-prefetch-url'
  NIX_PREFETCH_GIT = 'nix-prefetch-git'
  NIX_SHELL = 'nix-shell'

  SHA256_32 = %r(^[a-z0-9]{52}$)

  attr_reader :options

  def initialize(options)
    @options = options
  end

  def convert
    @cache = parse_gemset
    puts "resolving dependencies..." if $VERBOSE
    tree = GemfileDependencyTree.run(options)
    gems = {}

    tree.each do |name, node|
      gems[name] = convert_one(name, node)
      @cache[name] = gems[name]
    end

    gems
  end

  def convert_one(name, node)
    find_cached_spec(node) || convert_spec(node)
  end

  def convert_spec(spec, definition = nil)
    {
      'version' => spec.version.to_s,
      'groups' => spec.groups,
      'dependencies' => spec.dependencies,
      'source' => Source.new(spec, definition).convert
    }
  rescue => ex
    warn "Skipping #{spec.name}: #{ex}"
    puts ex.backtrace
    {}
  end

  def find_cached_spec(node)
    _, cached = @cache.find{|k, v|
      next unless k == node.name
      next unless cached_source = v['source']

      case spec_source = node.source
      when Bundler::Source::Git
        next unless cached_rev = cached_source['rev']
        next unless spec_rev = spec_source.options['revision']
        spec_rev == cached_rev
      when Bundler::Source::Rubygems
        v['version'] == node.version
      end
    }

    cached
  end

  def parse_gemset
    path = File.expand_path(options[:gemset])
    return {} unless File.file?(path)
    json = Bundix.sh(
      NIX_INSTANTIATE, '--eval', '-E', "builtins.toJSON(import #{path})")
    JSON.parse(json.strip.gsub(/\\"/, '"')[1..-2])
  end

  def self.object2nix(obj, level = 2, out = '')
    case obj
    when Hash
      out << "{\n"
      obj.sort_by{|k, v| k.to_s.downcase }.each do |(k, v)|
        out << ' ' * level
        if k.to_s =~ /^[a-zA-Z_-]+[a-zA-Z0-9_-]*$/
          out << k.to_s
        else
          object2nix(k, level + 2, out)
        end
        out << ' = '
        object2nix(v, level + 2, out)
        out << (v.is_a?(Hash) ? "\n" : ";\n")
      end
      out << (' ' * (level - 2)) << (level == 2 ? '}' : '};')
    when Array, Set
      out << '[' << obj.sort.map{|o| o.to_str.dump }.join(' ') << ']'
    when String
      out << obj.dump
    when Symbol
      out << obj.to_s.dump
    when true, false
      out << obj.to_s
    else
      fail obj.inspect
    end
  end

  def sh(*args)
    self.class.sh(*args)
  end

  def self.sh(*args)
    out, status = Open3.capture2e(*args)
    unless status.success?
      puts "$ #{args.join(' ')}" if $VERBOSE
      puts out if $VERBOSE
      fail "command execution failed: #{status}"
    end
    out
  end
end
