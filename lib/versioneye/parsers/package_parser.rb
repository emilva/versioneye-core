require 'versioneye/parsers/common_parser'
require 'semverly'

class PackageParser < CommonParser

  # Parser for package.json from npm. NodeJS
  # https://github.com/isaacs/node-semver
  # https://npmjs.org/doc/json.html
  # http://wiki.commonjs.org/wiki/Packages/1.1

  attr_reader :auth_token

  def parse ( url )
    return nil if url.to_s.empty?

    body = self.fetch_response_body( url )
    parse_content body
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def parse_content( content, token = nil )
    return nil if content.to_s.empty?
    return nil if (content =~ /Not\s+found/i)

    @auth_token = token # remember auth_token for outdated?

    data = from_json( content , false)
    return nil if data.nil?

    project = init_project( data )

    dependencies = data['dependencies']
    if dependencies && !dependencies.empty?
      parse_dependencies dependencies, project
    end

    dev_dependencies = data['devDependencies']
    if dev_dependencies && !dev_dependencies.empty?
      parse_dependencies dev_dependencies, project, Dependency::A_SCOPE_DEVELOPMENT
    end

    bundledDependencies = data['bundledDependencies']
    if bundledDependencies && !bundledDependencies.empty?
      parse_dependencies bundledDependencies, project, Dependency::A_SCOPE_BUNDLED
    end

    optionalDependencies = data['optionalDependencies']
    if optionalDependencies && !optionalDependencies.empty?
      parse_dependencies optionalDependencies, project, Dependency::A_SCOPE_OPTIONAL
    end

    if data.has_key?('jspm')
      symbolized_doc = from_json content
      parse_jspm_doc( symbolized_doc, project )
    end

    project.dep_number = project.dependencies.size

    project
  rescue => e
    log.error "parse_content: failed to parse Package.json"
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def parse_dependencies dependencies, project, scope = Dependency::A_SCOPE_COMPILE
    dependencies.each do |package_name, version_label|
      parse_line( package_name, version_label, project, scope )
    end
  end


  def parse_line( package_name, version_label, project, scope = Dependency::A_SCOPE_COMPILE )
    product = Product.fetch_product( Product::A_LANGUAGE_NODEJS, package_name )

    dependency = init_dependency( product, package_name )
    dependency.scope = scope
    dependency.project = project
    parse_requested_version( version_label, dependency, product )

    is_outdated = ProjectdependencyService.outdated?(dependency, product, @auth_token)
    project.out_number     += 1 if is_outdated
    project.unknown_number += 1 if product.nil?
    project.projectdependencies.push dependency
  end


  # It is important that this method is not writing int the database!
  #
  def parse_requested_version(version, dependency, product)
    if version.to_s.strip.empty?
      self.update_requested_with_current(dependency, product)
      return
    end

    version = version.to_s.strip
    version = version.gsub('"', '')
    version = version.gsub("'", '')
    version = version.gsub(/x\.x/i, "x")
    if version.match(/\Av\d.*/)
      version = version[1..version.length]
    end


    if product.nil?
      dependency.version_requested = version
      dependency.version_label     = version
      return
    end

    version = pre_process version

    if version.match(/\Agit[:|\+]/)
      commit_sha = version.split('#').to_a.last
      dependency[:version_requested] = 'GIT'
      dependency[:version_label] = commit_sha

    elsif version.match(/\Ahttps?:\/\//)
      version_label = extract_version_from_tarball_uri(version)
      version_label ||= 'HTTP'

      dependency[:version_requested]  = version_label
      dependency[:version_label]      = version_label
      dependency[:comperator]         = '='

    elsif version.match(/\Afile:\/\//)
      version_label = extract_version_from_tarball_uri(version)
      version_label ||= 'FILE'

      dependency[:version_requested]  = version_label
      dependency[:version_label]      = version_label
      dependency[:comperator]         = '='

    elsif /\w\/\w/.match?(version)
      # if github dependency
      repo_fullname, repo_ref = version.split('#', 2)
      repo_ref ||= 'master'

      dependency[:version_requested] = 'GITHUB'
      dependency[:version_label] = version
      dependency[:repo_fullname] = repo_fullname.to_s.strip
      dependency[:repo_ref]      = repo_ref


    elsif version.match(/\|\|/)
      parsed_versions = []
      versions = version.split("||")
      versions.each do |verso|
        proj_dep = init_dependency product, dependency.name
        parse_requested_version verso, proj_dep, product
        parsed_versions << proj_dep.version_requested
      end
      highest_version = VersionService.newest_version_from( parsed_versions )
      dependency.version_requested = highest_version
      dependency.version_label = version
      dependency.comperator = '||'

    elsif version.match(/\A\*\z/) or version.casecmp('latest') == 0
      # Start Matching. Matches everything in stable releases.
      dependency.version_requested = product.version
      dependency.version_label = version
      dependency.comperator = '='

    elsif version.match(/\A\X\z/)
      # Start Matching. Matches everything.
      dependency.version_requested = product.version
      dependency.version_label = 'X'
      dependency.comperator = '='

    elsif version.match(/\A=/)
      # Equals
      version.gsub!('=', '')
      version.gsub!(' ', '')
      dependency.version_requested = version
      dependency.version_label = version
      dependency.comperator = '='

    elsif version.match(/\A!=/)
      # Not equal to version
      version.gsub!('!=', '')
      version.gsub!(' ', '')
      newest_version = VersionService.newest_but_not(product.versions, version)
      dependency.version_requested = newest_version
      dependency.comperator = '!='
      dependency.version_label = version

    elsif version.match(/\A>=/)
      # Greater than or equal to
      version.gsub!('>=', '')
      version.gsub!(' ', '')
      newest_version = VersionService.greater_than_or_equal(product.versions, version)
      dependency.version_requested = newest_version.to_s
      dependency.comperator = '>='
      dependency.version_label = version

    elsif version.match(/\A>/)
      # Greater than version
      version.gsub!('>', '')
      version.gsub!(' ', '')
      newest_version = VersionService.greater_than(product.versions, version)
      dependency.version_requested = newest_version.to_s
      dependency.comperator = ">"
      dependency.version_label = version

    elsif version.match(/\A<=/)
      # Less than or equal to
      version.gsub!("<=", "")
      version.gsub!(" ", "")
      newest_version = VersionService.smaller_than_or_equal(product.versions, version)
      dependency.version_requested = newest_version.to_s
      dependency.comperator = "<="
      dependency.version_label = version

    elsif version.match(/\A\</)
      # Less than version
      version.gsub!("\<", "")
      version.gsub!(" ", "")
      newest_version = VersionService.smaller_than(product.versions, version)
      dependency.version_requested = newest_version.to_s
      dependency.comperator = "<"
      dependency.version_label = version

    elsif version.match(/\A~/)
      # Tilde Version Ranges -> Pessimistic Version Constraint
      # ~1.2.3 = >=1.2.3 <1.3.0

      dependency.version_label = version
      dependency.comperator = "~"

      ver = version.gsub("\>", "")
      ver = ver.gsub("~", "")
      ver = ver.gsub(" ", "")
      ver = ver.gsub(/\.\*\z/i, ".0")
      ver = ver.gsub(/\.x\z/i, ".0")

      highest_version = VersionService.version_tilde_newest(product.versions, ver)
      if highest_version
        dependency.version_requested = highest_version.to_s
      else
        dependency.version_requested = ver
      end

    elsif version.match(/\A\^/)
      # Compatible with operator
      dependency.comperator = "^"
      dependency.version_label = version

      ver = version.gsub("\>", "")
      ver = ver.gsub("^", "")
      ver = ver.gsub(" ", "")
      ver = ver.gsub(/\.\*\z/i, ".0")
      ver = ver.gsub(/\.x\z/i, ".0")
      highest_version = VersionService.newest_caret_version( product.versions, ver)
      dependency[:version_requested] = highest_version || ver

    elsif version.match(/\.x\z/i) || version.match(/\.\*\z/i)
      # X Version Ranges or .* version range
      versions = VersionService.wildcard_versions( product.versions, version, true )
      highest_version = VersionService.newest_version_from(versions)
      if highest_version
        dependency.version_requested = highest_version.to_s
      else
        dependency.version_requested = version
      end
      dependency.comperator = "="
      dependency.version_label = version

    elsif version.match(/ - /i)
      # Version Ranges
      version_splitted = version.split(" - ")
      start = version_splitted[0]
      stop = version_splitted[1]
      version_range   = VersionService.version_range(product.versions, start, stop)
      highest_version = VersionService.newest_version_from( version_range )
      if highest_version
        dependency.version_requested = highest_version.to_s
      else
        dependency.version_requested = version
      end
      dependency.comperator    = "="
      dependency.version_label = version

    elsif semver?(version)
      # when it is fixed version
      dependency.version_requested = version
      dependency.comperator        = "="
      dependency.version_label     = version

    elsif /\w+/.match?(version)
      matching_versions = product.versions.to_a.keep_if {|v| v[:tags].to_a.include?(version) }.to_a
      latest = VersionService.newest_version(matching_versions, 'unstable')
      # version was tag
      dependency[:version_requested] = latest[:version] if latest
      dependency[:version_requested] ||=  'UNKNOWN'
      dependency[:version_label]     = version
      dependency[:comperator]        = '='
    else
      log.warn "parse_requested_version: unknown version selection `#{version}`"

      dependency.version_requested = version
      dependency.comperator        = "="
      dependency.version_label     = version
    end
  end


  def init_project( data )
    project_name = data['name']
    project_name ||= "npm_project_#{ Time.now.to_i}"

    project = Project.new
    project.project_type = Project::A_TYPE_NPM
    project.language     = Product::A_LANGUAGE_NODEJS
    project.name         = project_name
    project.description  = data['description']
    project.version      = data['version']
    project
  end


  def init_dependency( product, name )
    dependency          = Projectdependency.new
    dependency.name     = name
    dependency.language = Product::A_LANGUAGE_NODEJS
    if product
      dependency.language        = product.language
      dependency.prod_key        = product.prod_key
      dependency.version_current = product.version
    end
    dependency
  end


  def pre_process version
    if version.match(/\A\d*\z/) || version.match(/\A\d*\.\d*\z/)
      version = "#{version}.*"
    end
    version
  end

  # parses dependency version from tarball URIs
  # returns:
  #   version_label, String, only if it had match
  #   nil - when no match
  # example urls:
  #   https://example.com/example-1.3.0.tgz
  #   file:///opt/storage/example-1.3.0.tgz
  def extract_version_from_tarball_uri(version)
    file_name = version.split('/').last
    m = file_name.to_s.match(/-(?<version>\d.+)\.tgz/)
    return if m.nil?

    m[:version].to_s.strip
  end



  # Parse JSPM dependencies
  def parse_jspm_doc(proj_doc, project)
    if proj_doc.nil? or proj_doc.has_key?(:jspm) == false
      log.error "project file has no `:jspm` subdocument"
      return nil
    end

    jspm_doc = proj_doc[:jspm]

    parse_jspm_dependencies(
      project, jspm_doc[:dependencies], Dependency::A_SCOPE_COMPILE, proj_doc[:registry]
    )
    parse_jspm_dependencies(
      project, jspm_doc[:devDependencies], Dependency::A_SCOPE_DEVELOPMENT, proj_doc[:registry]
    )

    parse_jspm_dependencies(
      project, jspm_doc[:peerDependencies], Dependency::A_SCOPE_OPTIONAL, proj_doc[:registry]
    )

    project
  rescue => e
    log.error "parse_jspm_doc: failed to parse JSPM document,\n `#{proj_doc}`"
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def parse_jspm_dependencies(project, deps, scope, default_registry = nil)
    deps.to_a.each do |pkg_id, dep_line|
      parse_jspm_dependency(project, pkg_id.to_s, dep_line, scope, default_registry)
    end

    project
  end


  def parse_jspm_dependency(project, pkg_id, dep_line, scope, default_registry)
    github_match = dep_line.to_s.strip.match(/\Agithub:(.*)(@.*)/i)
    if github_match
      version_label = "github#{github_match[2]}"
      product = nil
    else
      version_label = dep_line.to_s.split('@').last
      product = Product::fetch_product(Product::A_LANGUAGE_NODEJS, pkg_id)
    end

    dep = init_dependency( product, pkg_id )
    dep.project = project
    dep.scope = "jspm_#{scope}"
    if github_match
      dep.ext_link = "https://github.com/#{github_match[1]}"
    end

    parse_requested_version( version_label, dep, product )

    project.projectdependencies.push dep
    project.out_number     += 1 if ProjectdependencyService.outdated?( dep )
    project.unknown_number += 1 if product.nil?
    project
  end

  def semver?(version_label)
    res = SemVer.parse(version_label.to_s)
    (res.nil? == false)
  rescue
    false
  end
end
