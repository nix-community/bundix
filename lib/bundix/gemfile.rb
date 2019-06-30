class Bundix
  module GemfileHelpers
    def lockfile2gemfile(content)
      convert_lock(Bundler::LockfileParser.new(content)).join("\n")
    end

    def convert_lock(lock)
      header = ['# frozen_string_literal: true', '']
      lock.sources.each_with_object(header) do |source, out|
        case source
        when Bundler::Source::Rubygems
          convert_rubygems(lock, source, out)
        else
          raise "Unknown source: #{source}"
        end
      end
    end

    # TODO: sort to be reproducible
    def convert_rubygems(lock, source, out)
      out << "source '#{source.remotes.first}' do"
      lock.dependencies.each do |_name, dep|
        reqs = dep.requirements_list.reject { |r| r == '>= 0' }
        req = [dep.name, *reqs].map { |r| "'#{r}'" }.join(', ')
        out << "  gem #{req}"
      end
      out << 'end'
    end
  end
end
