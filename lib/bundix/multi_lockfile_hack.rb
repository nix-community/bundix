module Bundler::MultiLockfileHack

  Locks = Struct.new(:gemfile, :groups, :lockfile)

  def self.lockfiles; @lockfiles ||= {}; end

  def to_definition(lockfile, unlock)
    super
    DefinitionHack.new(lockfile, @dependencies, @sources, unlock, @ruby_version)
  end

  def generate_lockfile(options={})
    lockfile = options[:lockfile]
    gemfile = options[:gemfile]
    groups = options[:groups]
    raise 'Expected one of gemfile or groups' unless gemfile or groups

    groups &&= Array(groups)
    lockfile ||= [gemfile, groups, 'lock'].flatten.compact.join('.')
    Bundler::MultiLockfileHack.lockfiles[lockfile] = Locks.new(gemfile, groups, lockfile)
  end

  class DefinitionHack < Bundler::Definition
    def lock(filename)
      result = super(filename)
      Bundler::MultiLockfileHack.lockfiles.values.each{|data| _write_lock(data )}
      result
    end

    def _write_lock(data)
      if data.gemfile
        deps = Bundler::Dsl.new.eval_gemfile(data.gemfile)
      else
        deps = @dependencies
      end

      deps = deps.select{|d| (d.groups & data.groups).any?} if data.groups
      sources = SourceListHack.new(@sources)
      DefinitionHack2.new(@resolve, nil, deps, sources, @unlock, @ruby_version).lock(data.lockfile)
    end
  end


  if defined? Bundler::SourceList

    class SourceListHack < Bundler::SourceList
      attr_accessor :definition

      def initialize(sources)
        super()
        @path_sources = sources.path_sources
        @git_sources = sources.git_sources
        @rubygems_sources = (sources.rubygems_sources - [@rubygems_aggregate])
      end

      def lock_sources
        definition.sorted_sources(super)
      end
    end

  else

    SourceListHack = Array

  end

  class DefinitionHack2 < Bundler::Definition
    def initialize(resolve, *args)
      super(*args)
      @resolve = resolve
      @sources.definition = self unless @sources.is_a?(Array)
    end

    def resolve
      resolved = super
      names = @dependencies.flat_map{|dep| _resolve_dep_names(dep, resolved)}
      resolved.select{|spec| names.include? spec.name}
    end

    # recursively gather dependencies
    def _resolve_dep_names(dep, resolved)
      names = [dep.name]

      specs = resolved.select{|s| s.name == dep.name}
      names.concat specs.map(&:name)

      deps = specs.flat_map(&:dependencies).select{|dep| dep.type == :runtime}
      names.concat deps.map{|dep| _resolve_dep_names(dep, resolved)}
      names.flatten
    end

    def sorted_sources(sources=nil)
      sources ||= super()
      specs = resolve()
      sources.select{|src| src.nil? or specs.map(&:source).include?(src)}
    end

  end

end
