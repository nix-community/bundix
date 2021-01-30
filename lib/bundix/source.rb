class Bundix
  class Fetcher
    def sh(*args, &block)
      Bundix.sh(*args, &block)
    end

    def download(file, url)
      warn "Downloading #{file} from #{url}"
      uri = URI(url)
      open_options = {}

      unless uri.user
        inject_credentials_from_bundler_settings(uri)
      end

      if uri.user
        open_options[:http_basic_authentication] = [uri.user, uri.password]
        uri.user = nil
        uri.password = nil
      end

      begin
        open(uri.to_s, 'r', 0600, open_options) do |net|
          File.open(file, 'wb+') { |local|
            File.copy_stream(net, local)
          }
        end
      rescue OpenURI::HTTPError => e
        # e.message: "403 Forbidden" or "401 Unauthorized"
        debrief_access_denied(uri.host) if e.message =~ /^40[13] /
        raise
      end
    end

    def inject_credentials_from_bundler_settings(uri)
      @bundler_settings ||= Bundler::Settings.new(Bundler.root + '.bundle')

      if val = @bundler_settings[uri.host]
        uri.user, uri.password = val.split(':', 2)
      end
    end

    def debrief_access_denied(host)
      print_error(
        "Authentication is required for #{host}.\n" +
        "Please supply credentials for this source. You can do this by running:\n" +
        " bundle config packages.shopify.io username:password"
      )
    end

    def print_error(msg)
      msg = "\x1b[31m#{msg}\x1b[0m" if $stdout.tty?
      STDERR.puts(msg)
    end

    def nix_prefetch_url(url)
      dir = File.join(ENV['XDG_CACHE_HOME'] || "#{ENV['HOME']}/.cache", 'bundix')
      FileUtils.mkdir_p dir
      file = File.join(dir, url.gsub(/[^\w-]+/, '_'))

      download(file, url) unless File.size?(file)
      return unless File.size?(file)

      sh(
        Bundix::NIX_PREFETCH_URL,
        '--type', 'sha256',
        '--name', File.basename(url), # --name mygem-1.2.3.gem
        "file://#{file}",             # file:///.../https_rubygems_org_gems_mygem-1_2_3_gem
      ).force_encoding('UTF-8').strip
    rescue => ex
      puts ex
      nil
    end

    def nix_prefetch_git(uri, revision, submodules: false)
      home = ENV['HOME']
      ENV['HOME'] = '/homeless-shelter'

      args = []
      args << '--url' << uri
      args << '--rev' << revision
      args << '--hash' << 'sha256'
      args << '--fetch-submodules' if submodules

      sh(NIX_PREFETCH_GIT, *args)
    ensure
      ENV['HOME'] = home
    end

    def format_hash(hash)
      sh(NIX_HASH, '--type', 'sha256', '--to-base32', hash)[SHA256_32]
    end

    def fetch_local_hash(spec)
      has_platform = spec.platform && spec.platform != Gem::Platform::RUBY
      name_version = "#{spec.name}-#{spec.version}"
      filename = has_platform ? "#{name_version}-*" : name_version

      paths = spec.source.caches.map(&:to_s)
      Dir.glob("{#{paths.join(',')}}/#{filename}.gem").each do |path|
        if has_platform
          # Find first gem that matches the platform
          platform = File.basename(path, '.gem')[(name_version.size + 1)..-1]
          next unless Gem::Platform.match(platform)
        end

        hash = nix_prefetch_url(path)[SHA256_32]
        return format_hash(hash), platform if hash
      end

      nil
    end

    def fetch_remotes_hash(spec, remotes)
      remotes.each do |remote|
        hash, platform = fetch_remote_hash(spec, remote)
        return remote, format_hash(hash), platform if hash
      end

      nil
    end

    def fetch_remote_hash(spec, remote)
      has_platform = spec.platform && spec.platform != Gem::Platform::RUBY
      if has_platform
        # Fetch remote spec to determine the exact platform
        # Note that we can't simply use the local platform; the platform of the gem might differ.
        # e.g. universal-darwin-14 covers x86_64-darwin-14
        spec = spec_for_dependency(remote, spec.name, spec.version)
        return unless spec
      end

      uri = "#{remote}/gems/#{spec.full_name}.gem"
      result = nix_prefetch_url(uri)
      return unless result

      return result[SHA256_32], spec.platform&.to_s
    rescue => e
      puts "ignoring error during fetching: #{e}"
      puts e.backtrace
      nil
    end

    def spec_for_dependency(remote, name, version)
      sources = Gem::SourceList.from([remote])
      Gem::SpecFetcher.new(sources).spec_for_dependency(Gem::Dependency.new(name, version)).first&.first&.first
    end
  end

  class Source < Struct.new(:spec, :fetcher)
    def convert
      case spec.source
      when Bundler::Source::Rubygems
        convert_rubygems
      when Bundler::Source::Git
        convert_git
      when Bundler::Source::Path
        convert_path
      else
        pp spec
        fail 'unknown bundler source'
      end
    end

    def convert_path
      {
        version: spec.version.to_s,
        source: {
          type: 'path',
          path: spec.source.path,
        },
      }
    end

    def convert_rubygems
      remotes = spec.source.remotes.map{|remote| remote.to_s.sub(/\/+$/, '') }
      hash, platform = fetcher.fetch_local_hash(spec)
      remote, hash, platform = fetcher.fetch_remotes_hash(spec, remotes) unless hash
      fail "couldn't fetch hash for #{spec.full_name}" unless hash

      version = spec.version.to_s
      if platform && platform != Gem::Platform::RUBY
        version += "-#{platform}"
      end

      puts "#{hash} => #{spec.name}-#{version}.gem" if $VERBOSE

      {
        version: version,
        source: {
          type: 'gem',
          remotes: (remote ? [remote] : remotes),
          sha256: hash,
        },
      }
    end

    def convert_git
      revision = spec.source.options.fetch('revision')
      uri = spec.source.options.fetch('uri')
      submodules = !!spec.source.submodules
      output = fetcher.nix_prefetch_git(uri, revision, submodules: submodules)
      # FIXME: this is a hack, we should separate $stdout/$stderr in the sh call
      hash = JSON.parse(output[/({[^}]+})\s*\z/m])['sha256']
      fail "couldn't fetch hash for #{spec.full_name}" unless hash
      puts "#{hash} => #{uri}" if $VERBOSE

      {
        version: spec.version.to_s,
        source: {
          type: 'git',
          url: uri.to_s,
          rev: revision,
          sha256: hash,
          fetchSubmodules: submodules,
        },
      }
    end
  end
end
