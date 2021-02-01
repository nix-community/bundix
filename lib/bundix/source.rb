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

    def format_hash(hash)
      sh(NIX_HASH, '--type', 'sha256', '--to-base32', hash)[SHA256_32]
    end

    def fetch_local_hash(spec)
      spec.source.caches.each do |cache|
        path = File.join(cache, "#{spec.full_name}.gem")
        next unless File.file?(path)
        hash = nix_prefetch_url(path)[SHA256_32]
        return format_hash(hash) if hash
      end

      nil
    end

    def fetch_remotes_hash(spec, remotes)
      remotes.each do |remote|
        hash = fetch_remote_hash(spec, remote)
        return remote, format_hash(hash) if hash
      end

      nil
    end

    def fetch_remote_hash(spec, remote)
      uri = "#{remote}/gems/#{spec.full_name}.gem"
      result = nix_prefetch_url(uri)
      return unless result
      result[SHA256_32]
    rescue => e
      puts "ignoring error during fetching: #{e}"
      puts e.backtrace
      nil
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
        type: "path",
        path: spec.source.path
      }
    end

    def convert_rubygems
      remotes = spec.source.remotes.map{|remote| remote.to_s.sub(/\/+$/, '') }
      hash = fetcher.fetch_local_hash(spec)
      remote, hash = fetcher.fetch_remotes_hash(spec, remotes) unless hash
      fail "couldn't fetch hash for #{spec.full_name}" unless hash
      puts "#{hash} => #{spec.full_name}.gem" if $VERBOSE

      { type: 'gem',
        remotes: (remote ? [remote] : remotes),
        sha256: hash }
    end

    def convert_git
      revision = spec.source.options.fetch('revision')
      uri = spec.source.options.fetch('uri')
      submodules = !!spec.source.submodules
      ref, branch, tag = spec.source.options.values_at('ref', 'branch', 'tag')
      unless ref.nil?
        # Didn't find a good enough solution for this since Bundler accepts
        # SHA1's that are shorter than 40 characters, which means we don't know
        # if the ref in the Gemfile is a hash or a branch/tag name.
        #
        # (builtins.fetchGit only takes a tag/branch as 'ref')
        #
        # One possible solution if we could discriminate between a short SHA1
        # and tags/refs would be to clone the repo and do `git name-rev $ref`.
        #
        # Leaving this as a hint for anyone wanting to implement this.
        fetcher.print_error(
           "Please provide a 40 character SHA1 as 'ref' in Gemfile.\n" +
           "If you tried providing a tag/branch name please use 'tag' or 'branch' respectively in the Gemfile.\n" +
           "More info: https://bundler.io/guides/git.html"
        )
        raise
      end
      unless branch.nil?
        ref = branch
      end
      unless tag.nil?
        ref = tag
      end
      # Setting ref to master. This should work since Bundler doesn't handle
      # repos without a master branch that hasn't 'branch' or 'tag' specified
      # in the Gemfile explicitly
      ref = 'master' unless ref

      { type: 'builtins-git',
        url: uri.to_s,
        rev: revision,
        ref: ref,
        submodules: submodules }
    end
  end
end
