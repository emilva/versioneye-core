require 'versioneye/parsers/common_parser'
require 'versioneye/parsers/gemfile_parser'

class GemfilelockParser < GemfileParser

  # Parser for Gemfile.lock. For Ruby.
  # http://gembundler.com/man/gemfile.5.html
  # http://docs.rubygems.org/read/chapter/16#page74
  #
  def parse(url)
    return nil if url.nil?

    content = self.fetch_response(url).body
    return nil if content.nil?

    parse_content( content )
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

  def parse_content(content, token = nil)
    return nil if content.to_s.empty?
    return nil if content.to_s.strip.eql?('Not Found')

    dependecies_matcher = /([\w|\d|\.|\-|\_]+) (\(.*\))/

    matches = content.scan( dependecies_matcher )
    deps = self.build_dependencies(matches)
    project                     = init_project
    project.projectdependencies = deps[:projectdependencies]
    project.unknown_number      = deps[:unknown_number]
    project.out_number          = deps[:out_number]
    project.dep_number          = project.dependencies.size
    project
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

  def build_dependencies( matches )
    unknowns, out_number = 0, 0
    deps = Hash.new

    matches.each do |row|
      name = get_name row

      version_match = row[1]
      version = version_match.gsub('(', '').gsub(')', '')
      
      #removes -x64,-x86, -mingw32 etc from version id
      version = strip_platform_exts(version)

      dependency = Projectdependency.new

      product = fetch_product_for row[0]
      if product
        dependency.name            = product.name
        dependency.language        = product.language
        dependency.prod_key        = product.prod_key
        dependency.version_current = product.version
      else
        dependency.name = name
        dependency.language = language
        unknowns += 1
      end
      parse_requested_version(version, dependency, product)

      dep = deps[name]
      if dep.nil? or !dep.comperator.eql?('=')
        deps[name] = dependency
      end
    end

    data = Array.new
    deps.each do |k, v|
      if ProjectdependencyService.outdated?( v )
        out_number += 1
      end
      data.push v
    end

    {:unknown_number => unknowns, :out_number => out_number, :projectdependencies => data}
  end


  def get_name row
    name = row[0]
    if name.to_s.match(/\Arails-assets-/)
      name = name.gsub("rails-assets-", "")
    end
    name
  end

end
