require 'bundler'
require 'set'

class Bundix::GemfileDependencyTree
  Spec = Struct.new(:name, :groups, :source, :version, :dependencies)

  attr_reader :options

  def self.run(options)
    definition = Bundler::Dsl.evaluate(Bundler.settings[:gemfile], nil, {})
    specs =
      if options.fetch(:cache)
        puts "resolving #{Bundler.settings[:gemfile]} dependencies with cache" if $VERBOSE
        definition.resolve_with_cache!
      else
        puts "resolving #{Bundler.settings[:gemfile]} dependencies remotely" if $VERBOSE
        definition.resolve_remotely!
      end

    unless Bundler.settings[:frozen]
      puts "writing #{Bundler.settings[:lockfile]}" if $VERBOSE
      definition.lock(Bundler.settings[:lockfile])
    end

    result = {}
    definition.dependencies.each do |dependency|
      new(dependency, specs, dependency.groups, options).run([], result)
    end

    result
  end

  def initialize(dep, specs, groups, options)
    @dep = dep
    @spec = specs.find{|s| s.name == dep.name }
    @groups = groups.map(&:to_s)
    @options = options
    @children = dependencies.map{|d| self.class.new(d, specs, groups, options) }
  end

  def run(seen = Set.new, result = {})
    children = @children.reject{|c| seen.include?(c.name) }
    add_group(result, @spec)

    children.each do |child|
      seen << child.name
      child.run(seen, result)
    end

    result
  end

  def name
    @spec.name
  end

  private

  def add_group(result, dep)
    if result[dep.name]
      result[dep.name].groups |= @groups
    else
      result[dep.name] = Spec.new(
        dep.name,
        @groups,
        dep.source,
        dep.version.to_s,
        dependencies.map(&:name)
      )
    end
  end

  def dependencies
    if options[:development_dependencies]
      @spec.dependencies
    else
      @spec.dependencies.reject{|d| d.type == :development }
    end
  end
end
