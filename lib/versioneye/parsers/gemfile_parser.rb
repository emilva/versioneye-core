require 'versioneye/parsers/common_parser'

class GemfileParser < CommonParser

  attr_accessor :language, :type, :keyword

  def language
    Product::A_LANGUAGE_RUBY
  end

  def type
    Project::A_TYPE_RUBYGEMS
  end

  def keyword
    'gem'
  end


  # Parser for Gemfile. For Ruby.
  # http://gembundler.com/man/gemfile.5.html
  # http://guides.rubygems.org/patterns/#semantic_versioning
  #
  def parse( url )
    return nil if url.nil? || url.empty?

    gemfile = fetch_response_body( url )
    return nil if gemfile.nil?

    parse_content( gemfile )
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def parse_content( gemfile, token = nil )
    return nil if gemfile.to_s.strip.empty?
    return nil if gemfile.to_s.strip.eql?('Not Found')

    gemfile = gemfile.encode("UTF-8")
    project = init_project
    gemfile.each_line do |line|
      parse_line( line, project )
    end
    project.dep_number = project.dependencies.size
    update_project gemfile, project
    project
  rescue => e
    log.error "ERROR in parse_content(#{gemfile}) -> #{e.message}"
    log.error e.backtrace.join("\n")
    nil
  end


  def parse_line( line, project )
    if !line.valid_encoding?
      line = line.unpack('C*').pack('U*')
      line = line.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    end
    line          = line.delete("\n")
    line          = line.delete("\t")
    line          = line.gsub(/require:.+\[.+\]/i, "")
    line          = line.gsub(/:require.+\[.+\]/i, "")
    line_elements = fetch_line_elements( line )
    gem_name      = fetch_gem_name( line_elements )

    return nil if gem_name.to_s.empty?

    version    = fetch_version( line_elements )
    product    = fetch_product_for gem_name
    dependency = init_dependency( product, gem_name )

    parse_requested_version( version, dependency, product )

    project.projectdependencies.push dependency
    project.out_number     += 1 if ProjectdependencyService.outdated?( dependency )
    project.unknown_number += 1 if product.nil?
  rescue => e
    log.error "ERROR in parse_line(#{line}) -> #{e.message}"
    log.error e.backtrace.join("\n")
    nil
  end


  # It is important that this method is not writing into the database!
  def parse_requested_version(version_number, dependency, product)
    if version_number.nil? || version_number.empty?
      self.update_requested_with_current(dependency, product)
      return
    end

    if product.nil?
      dependency.version_requested = version_number
      dependency.version_label     = version_number
      return
    end

    version = String.new( version_number )

    if version.match(/\A=/)
      # Equals
      version.gsub!('=', '')
      version.gsub!(' ', '')
      dependency.version_requested = version
      dependency.version_label     = version
      dependency.comperator        = '='

    elsif version.match(/\A!=/)
      # Not equal to version
      version.gsub!('!=', '')
      version.gsub!(' ', '')
      newest_version = VersionService.newest_but_not( product.versions, version)
      dependency.version_requested = newest_version
      dependency.comperator        = '!='
      dependency.version_label     = version

    elsif version.match(/\A>=/)
      # Greater than or equal to
      version.gsub!('>=', '')
      version.gsub!(' ', '')
      newest_version = VersionService.greater_than_or_equal( product.versions, version)
      dependency.version_requested = newest_version.to_s
      dependency.comperator        = '>='
      dependency.version_label     = version

    elsif version.match(/\A>/)
      # Greater than version
      version.gsub!('>', '')
      version.gsub!(' ', '')
      newest_version = VersionService.greater_than( product.versions, version )
      dependency.version_requested = newest_version.to_s
      dependency.comperator        = ">"
      dependency.version_label     = version

    elsif version.match(/\A<=/)
      # Less than or equal to
      version.gsub!("<=", "")
      version.gsub!(" ", "")
      newest_version = VersionService.smaller_than_or_equal( product.versions, version )
      dependency.version_requested = newest_version.to_s
      dependency.comperator        = "<="
      dependency.version_label     = version

    elsif version.match(/\A\</)
      # Less than version
      version.gsub!("\<", "")
      version.gsub!(" ", "")
      newest_version = VersionService.smaller_than( product.versions, version )
      dependency.version_requested = newest_version.to_s
      dependency.comperator        = "<"
      dependency.version_label     = version

    elsif version.match(/\A~>/)
      # Approximately greater than -> Pessimistic Version Constraint
      ver = version.gsub("~>", "")
      ver = ver.gsub(" ", "")
      starter         = VersionService.version_approximately_greater_than_starter( ver )
      versions        = VersionService.versions_start_with( product.versions, starter )
      highest_version = VersionService.newest_version_from( versions )
      if highest_version
        dependency.version_requested = highest_version.to_s
      else
        dependency.version_requested = ver
      end
      dependency.comperator = "~>"
      dependency.version_label = ver

    elsif version.match(/^git:/) or version.match(/\A:git/)
      dependency.version_requested = "GIT"
      dependency.version_label     = "GIT"
      dependency.comperator        = "="

    elsif version.match(/^path:/) or version.match(/\A:path/)
      dependency.version_requested = "PATH"
      dependency.version_label     = "PATH"
      dependency.comperator        = "="

    else
      dependency.version_requested = version
      dependency.comperator        = "="
      dependency.version_label     = version
    end
  end


  def fetch_line_elements( line )
    line = replace_comments( line )
    line = line.strip
    line.split(",")
  end


  def fetch_gem_name( line_elements )
    gem_name = line_elements.first
    return nil if gem_name.nil? || gem_name.empty?
    return nil if gem_name.match(/^#{keyword} /).nil? # TODO check git as well !
    gem_name.gsub!("#{keyword} ", "")
    gem_name = gem_name.strip
    gem_name = gem_name.gsub('"', '')
    gem_name = gem_name.gsub("'", "")
    gem_name.split(" ").first
  end


  def fetch_version( line_elements )
    version = ""
    line_elements.each_with_index do |element, index|
      next if index == 0
      element = element.strip
      if element.match(/^require:/) || element.match(/\A:require/) || element.match(/\Arequire/)
        next
      elsif element.match(/\A:group/) or element.match(/^group:/)
        next
      elsif element.match(/\A:development/) or element.match(/^development:/)
        next
      elsif element.match(/\A:test/) or element.match(/^test:/)
        next
      elsif element.match(/\A:platforms/) or element.match(/^platforms:/)
        next
      elsif element.match(/\A:platform/) or element.match(/^platform:/)
        next
      elsif element.match(/\A:engine/) or element.match(/^engine:/)
        next
      elsif element.match(/\A:engine_version/) or element.match(/^engine_version:/)
        next
      elsif element.match(/\A:branch/) or element.match(/^branch:/)
        next
      elsif element.match(/\A:tag/) or element.match(/^tag:/)
        next
      elsif element.match(/\A:path/) or element.match(/^path:/)
        version = element
        break
      elsif element.match(/\A:git/) or element.match(/^git:/)
        version = element
        break
      elsif element.match(/\A:github/i) or element.match(/^github:/i)
        version = element
        break
      else
        version = element if gem_requirement?(element)
      end
    end

    #removes -x64,-x86, -mingw32 etc from version id
    version = strip_quotes(version)
    strip_platform_exts(version)
  end


  def replace_comments( value )
    return nil unless value
    comment = value.match(/#.*/)
    if comment
      value.gsub!(comment[0], "")
    end
    value
  end


  def init_project( url = nil )
    project = Project.new
    project.project_type = type
    project.language     = language
    project.url          = url
    project
  end


  def init_dependency( product, gem_name )
    dependency          = Projectdependency.new
    dependency.name     = gem_name
    dependency.language = language
    if product
      dependency.name            = product.name
      dependency.language        = product.language
      dependency.prod_key        = product.prod_key
      dependency.version_current = product.version
    end
    dependency
  end


  def fetch_product_for key
    return nil if key.to_s.empty?
    if key.to_s.match(/\Arails-assets-/)
      new_key = key.gsub("rails-assets-", "")
      return Product.fetch_bower( new_key )
    else
      return Product.fetch_product( language, key )
    end
  rescue => e
    log.error "ERROR in fetch_product_for(#{key}) -> #{e.message}"
    log.error e.backtrace.join("\n")
    nil
  end


  def update_project gemfile, project
    gemfile.each_line do |line|
      if line.match(/\Aname /)
        project.name = line.gsub("name", "").gsub("\n", "").gsub("'", "").gsub("\"", "").strip
      elsif line.match(/\Aversion /)
        project.version = line.gsub("version", "").gsub("\n", "").gsub("'", "").gsub("\"", "").strip
      elsif line.match(/\Adescription /)
        project.description = line.gsub("description", "").gsub("\n", "").gsub("'", "").gsub("\"", "").strip
      elsif line.match(/\Alicense /)
        project.license = line.gsub("license", "").gsub("\n", "").gsub("'", "").gsub("\"", "").strip
      end
    end
    nil
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end

  def strip_platform_exts(version)
    blacklist = Set.new ['x86', 'x64', 'java', 'mingw32'] #from nokogiri versions
    tokens = version.to_s.split('-')
    tokens = tokens.reduce([]) do |acc, tkn|
      unless blacklist.include? tkn.downcase
        #only add tokens that arenot in the blacklist
        acc << tkn
      end

      acc
    end

    tokens.join('-')
  end

  private

  def strip_quotes(version)
    version = version.gsub('"', '')
    version.gsub("'", '')
  end

  def gem_requirement?(requirement)
    begin
      requirement = strip_quotes(requirement)
      Gem::Requirement.parse(requirement)
      true
    rescue Gem::Requirement::BadRequirementError
      false
    end
  end

end
