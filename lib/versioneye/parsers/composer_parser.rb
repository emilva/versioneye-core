require 'versioneye/parsers/common_parser'

class ComposerParser < CommonParser

  attr_accessor :composer_json, :token

  # Parser for composer.json files from composer, packagist.org. PHP
  # http://getcomposer.org/doc/01-basic-usage.md
  # https://igor.io/2013/02/07/composer-stability-flags.html
  #
  def parse url
    data = self.fetch_data url
    parse_content( data )
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

  def parse_content( data, token = nil )
    if data.to_s.empty?
      log.error "data is empty!"
      return nil
    end
    if data.to_s.strip.eql?('Not Found')
      log.error "data = Not Found"
      return nil
    end

    self.token = token
    json_content = from_json( data, false )
    self.composer_json = json_content
    project = init_project

    dependencies = json_content['require']
    if dependencies && !dependencies.empty?
      parse_dependencies dependencies, project, json_content, Dependency::A_SCOPE_COMPILE
    end

    dependencies = json_content['require-dev']
    if dependencies && !dependencies.empty?
      parse_dependencies dependencies, project, json_content, Dependency::A_SCOPE_DEVELOPMENT
    end

    dependencies = json_content['require-test']
    if dependencies && !dependencies.empty?
      parse_dependencies dependencies, project, json_content, Dependency::A_SCOPE_TEST
    end

    self.update_project( project, json_content )
    project
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def parse_dependencies dependencies, project, json_content, scope = Dependency::A_SCOPE_COMPILE
    dependencies.each do |key, value|
      next if key.to_s.match(/\Aext-/i) # Skip PHP extensions because we do't have infos about them

      self.process_dependency( key, value, project, json_content, scope )
    end
  end


  def fetch_data url
    return nil if url.nil?

    response = self.fetch_response(url)
    return nil if response.nil?

    response.body
  end


  def process_dependency prod_key, version, project, data, scope = Dependency::A_SCOPE_COMPILE
    product    = fetch_product_for prod_key
    dependency = init_projectdependency( prod_key, product )
    dependency.scope = scope
    parse_requested_version( version, dependency, product )
    project.unknown_number += 1 if dependency.unknown?
    project.out_number     += 1 if ProjectdependencyService.outdated?( dependency )
    project.projectdependencies.push dependency
  end


  def update_project project, data
    name                = data['name']
    description         = data['description']
    license             = data['license']
    project.name        = name if name
    project.description = description if description
    project.license     = license if license
    project.dep_number  = project.dependencies.size
  end


  # It is important that this method is NOT writing into the database!
  #
  def parse_requested_version version, dependency, product
    if (version.nil? || version.empty?) && !product.nil?
      update_requested_with_current(dependency, product)
      return
    end

    version = version.strip
    version = version.gsub('"', '')
    version = version.gsub("'", '')
    version = version.gsub(/^v/, '')

    dependency.version_label = String.new(version)

    # Ignore cases like => "dev-master | ^1.0"
    if version.match(/.+\|.+/).nil?
      dependency.stability = VersionTagRecognizer.stability_tag_for version
      VersionTagRecognizer.remove_minimum_stability version
    else
      dependency.stability = VersionTagRecognizer::A_STABILITY_STABLE
    end

    if !product.nil? && version.empty?
      update_requested_with_current(dependency, product)
      return
    end

    if product.nil?
      ext_link = fetch_ext_link dependency.name, version
      if !ext_link.to_s.empty?
        dependency.ext_link = ext_link
      end
      dependency.version_requested = version
      return nil
    end

    case
    when version.match(/\|/)
      versions = []
      parts = version.split("|")
      parts.each do |verso|
        project_dependency = init_projectdependency product.name, product
        parse_requested_version verso, project_dependency, product
        versions << project_dependency.version_requested
      end
      highest_version = VersionService.newest_version_from( versions, dependency.stability )
      dependency.version_requested = highest_version

    when version.match(/,/)

      stability = dependency.stability
      versions = VersionService.from_ranges product.versions, version
      highest_version = VersionService.newest_version_from( versions, stability )
      if highest_version
        dependency.version_requested = highest_version.to_s
      else
        dependency.version_requested = version
      end
      dependency.comperator = "="

    when version.match(/.\*\z/)
      # WildCards. 1.0.* => 1.0.0 | 1.0.2 | 1.0.20
      ver = version.gsub("*", "")
      ver = ver.gsub(" ", "")
      highest_version = VersionService.newest_version_from_wildcard( product.versions, ver, dependency.stability )
      if highest_version
        dependency.version_requested = highest_version
      else
        dependency.version_requested = version
      end
      dependency.comperator = "="

    when version.empty? || version.match(/\A\*\z/)
      # This case is not allowed. But we handle it anyway. Because we are fucking awesome!
      dependency.version_requested = VersionService.newest_version_number( product.versions, dependency.stability )
      dependency.version_label = "*"
      dependency.comperator = "="

    when version.match(/\A>=/)
      # Greater than or equal to
      version.gsub!(">=", "")
      version.gsub!(" ", "")
      greater_than_or_equal = VersionService.greater_than_or_equal( product.versions, version)
      dependency.version_requested = greater_than_or_equal.version
      dependency.comperator = ">="

    when version.match(/\A>/)
      # Greater than version
      version.gsub!(">", "")
      version.gsub!(" ", "")
      greater_than = VersionService.greater_than( product.versions, version)
      dependency.version_requested = greater_than.version
      dependency.comperator = ">"

    when version.match(/\A<=/)
      # Less than or equal to
      version.gsub!("<=", "")
      version.gsub!(" ", "")
      smaller_or_equal = VersionService.smaller_than_or_equal( product.versions, version )
      dependency.version_requested = smaller_or_equal.version
      dependency.comperator = "<="

    when version.match(/\A\</)
      # Less than version
      version.gsub!("\<", "")
      version.gsub!(" ", "")
      smaller_than = VersionService.smaller_than( product.versions, version )
      dependency.version_requested = smaller_than.version
      dependency.comperator = "<"

    when version.match(/\A!=/)
      # Not equal to version
      version.gsub!("!=", "")
      version.gsub!(" ", "")
      newest_but_not = VersionService.newest_but_not( product.versions, version )
      dependency.version_requested = newest_but_not.version
      dependency.comperator = "!="

    when version.match(/\A~/)
      # Approximately greater than -> Pessimistic Version Constraint
      version.gsub!("~", "")
      version.gsub!(" ", "")
      highest_version = VersionService.version_tilde_newest( product.versions, version )
      if highest_version
        dependency.version_requested = highest_version.to_s
      else
        dependency.version_requested = version
      end
      dependency.comperator = "~"

    when version.match(/\A\^/)
      dependency.comperator = "^"
      dependency.version_label = version

      version_label = version.gsub(/\A\^\s*/, '').to_s.strip
      highest_version = VersionService.newest_caret_version(
        product.versions, version_label
      )
      dependency[:version_requested] = (highest_version || version_label)

    else # =
      dependency.version_requested = version
      dependency.comperator = "="
    end

  end


  def fetch_ext_link name, branch
    return nil if self.composer_json.nil?

    repos = self.composer_json['repositories']
    return nil if (repos.nil? || repos.empty?)

    repos.each do |repo|
      repo_type = repo['type']
      repo_url  = repo['url']
      next if !repo_type.eql?('vcs')

      repo = repo_url.gsub('https://github.com/', '')
      file = fetch_file_from_branch( repo, "composer.json", branch, self.token )
      if file.nil? && !branch.to_s.eql?('master')
        branch = 'master'
        file = fetch_file_from_branch( repo, "composer.json", branch, self.token )
      end
      if file.nil?
        log.error "fetch_ext_link: Could not fetch file from #{repo}"
        next
      end
      file_txt = GitHubService.pure_text_from file
      json_content = JSON.parse( file_txt )
      if json_content['name'].to_s.eql?(name)
        return "#{repo_url}/tree/#{branch}"
      end
    end
    return nil
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def fetch_file_from_branch repo, file, branch, token
    Github.fetch_project_file_from_branch repo, file, branch, token
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  # TODO write tests
  #
  def dependency_in_repositories? dependency, data
    return false if (dependency.nil? || data.nil?)

    repos = data['repositories']
    return false if (repos.nil? || repos.empty?)

    repos.each do |repo|
      repo_name = repo['package']['name']
      repo_version = repo['package']['version']
      repo_link = repo['package']['dist']['url']
      if repo_name.eql?(dependency.name)
        dependency.ext_link = repo_link
        dependency.version_current = repo_version
        return true
      end
    end
    return false
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end


  def init_project url = nil
    project              = Project.new
    project.project_type = Project::A_TYPE_COMPOSER
    project.language     = Product::A_LANGUAGE_PHP
    project.url          = url
    project
  end


  def fetch_product_for key
    key = key.to_s.strip
    return nil if key.empty?

    case key
    when /\Anpm\-asset\//
      new_key = key.gsub("npm-asset/", '').to_s.strip
      Product.fetch_product( Product::A_LANGUAGE_NODEJS, new_key )

    when /\Abower\-asset\//
      new_key = key.gsub(/\Abower-asset\//, '').to_s.strip
      Product.fetch_bower( new_key )

    else
      Product.fetch_product( Product::A_LANGUAGE_PHP, key )
    end

  end

    private
    def init_projectdependency key, product
      dependency          = Projectdependency.new
      dependency.name     = key
      dependency.language = Product::A_LANGUAGE_PHP
      if product
        dependency.name            = product.name
        dependency.language        = product.language
        dependency.prod_key        = product.prod_key
        dependency.version_current = product.version
      end
      dependency
    end


    # This method exist in CommonParser, too!
    # This is just a copy with a different implementation for Composer!
    #
    def update_requested_with_current dependency, product
      if product && product.version
        dependency.version_requested = VersionService.newest_version_number( product.versions, dependency.stability )
      else
        dependency.version_requested = "UNKNOWN"
      end
      dependency
    end

end
