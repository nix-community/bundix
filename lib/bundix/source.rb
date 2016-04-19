require 'pp'

class Bundix
  class Source < Struct.new(:spec, :definition)
    def convert
      case spec.source
      when Bundler::Source::Rubygems
        convert_rubygems
      when Bundler::Source::Git
        convert_git
      else
        pp spec
        fail 'unkown bundler source'
      end
    end

    def sh(*args)
      Bundix.sh(*args)
    end

    def nix_prefetch_url(*args)
      sh(NIX_PREFETCH_URL, '--type', 'sha256', *args)
    rescue
      nil
    end

    def nix_prefetch_git(uri, revision)
      home = ENV['HOME']
      ENV['HOME'] = '/homeless-shelter'
      sh(NIX_PREFETCH_GIT, '--url', uri, '--rev', revision, '--hash', 'sha256', '--leave-dotGit')
    ensure
      ENV['HOME'] = home
    end

    def fetch_local_hash(spec)
      spec.source.caches.each do |cache|
        path = File.join(cache, "#{spec.name}-#{spec.version}.gem")
        next unless File.file?(path)
        hash = nix_prefetch_url("file://#{path}")[SHA256_32]
        return hash if hash
      end

      nil
    end

    def fetch_remotes_hash(spec, remotes)
      remotes.each do |remote|
        hash = fetch_remote_hash(spec, remote)
        return remote, hash if hash
      end

      nil
    end

    def fetch_remote_hash(spec, remote)
      uri = "#{remote}/gems/#{spec.name}-#{spec.version}.gem"
      nix_prefetch_url(uri)[SHA256_32]
    rescue
      nil
    end

    def convert_rubygems
      hash = fetch_local_hash(spec)

      if definition && definition.source
        remotes = [definition.source.remotes.first.to_s.sub(/\/+$/, '')]
      else
        remotes = spec.source.remotes.map{|r| r.to_s.sub(/\/+$/, '') }
      end

      _, hash = fetch_remotes_hash(spec, remotes) unless hash
      fail "couldn't fetch hash for #{spec.name}-#{spec.version}" unless hash
      puts "#{hash} => #{spec.name}-#{spec.version}.gem" if $VERBOSE

      { 'type'    => 'gem',
        'remotes' => remotes,
        'sha256'  => hash }
    end

    def convert_git
      if definition
        rev = definition.source.revision
        uri = definition.source.uri
      else
        rev = spec.source.revision
        uri = spec.source.uri
      end

      output = nix_prefetch_git(uri, rev)
      # FIXME: this is a hack, we should separate $stdout/$stderr in the sh call
      hash = JSON.parse(output[/({[^}]+})\s*\z/m])['sha256']
      fail "couldn't fetch hash for #{spec.name}-#{spec.version}" unless hash
      puts "#{hash} => #{uri}" if $VERBOSE

      { 'type'            => 'git',
        'url'             => uri,
        'rev'             => rev,
        'sha256'          => hash,
        'fetchSubmodules' => false }
    end
  end
end
