class Bundix
  class ShellNixContext < Struct.new(:project, :ruby, :gemfile, :lockfile, :gemset)
    def self.from_hash(hash)
      new(*hash.values_at(*members))
    end

    def bind
      binding
    end

    def path_for(file)
      "./#{Pathname(file).relative_path_from(Pathname('./'))}"
    end

    def gemfile_path
      path_for(gemfile)
    end

    def lockfile_path
      path_for(lockfile)
    end

    def gemset_path
      path_for(gemset)
    end
  end
end
