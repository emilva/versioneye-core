require 'versioneye/parsers/common_parser'
require 'semverly'

# Parser for cargo.toml used in Rust projects.
# official doc: http://doc.crates.io/specifying-dependencies.html
# uses semver implementation: https://github.com/steveklabnik/semver-parser

class CargoParser < CommonParser
  FIXNUM_MAX = (2**(0.size * 8 -2) -1)

  def parse(url)
    return nil if url.to_s.empty?

    content = self.fetch_response_body url
    parse_content content
  rescue => e
    log.error e.message
    log.error e.backtrace.join('\n')
    nil
  end

  # params:
  #   content - string, content of Cargo.toml file
  #   token - empty param to comply with CommonParser
  def parse_content(content, token = nil)
    return nil if content.to_s.empty?
    return nil if content.to_s.strip.eql?('Not Found')

    doc = from_toml(content)
    if doc.nil?
      log.error "Failed to parse Cargo.toml content: #{content}"
      return nil
    end

    project = init_project doc
    parse_dependencies doc, project, Dependency::A_SCOPE_COMPILE
    parse_platform_dependencies doc[:target], project, Dependency::A_SCOPE_COMPILE

    project.dep_number = project.dependencies.size
    project
  rescue => e
    log.error e.message
    log.error e.backtrace.join('\n')
    nil
  end

  def parse_platform_dependencies(platforms, project, scope)
    platform_deps = []
    platforms.to_a.each do |target_key, target_docs|
      target_id = extract_target_id(target_key)
      log.info "Going to parse #{target_id} dependencies"

      deps = parse_dependencies(target_docs, project, scope, target_id)
      platform_deps += deps
    end

    platform_deps
  end

  def extract_target_id(target_key)
    id = target_key.to_s.strip

    # extract target id from cfg
    if id =~ /\Acfg\(/i
      m = id.to_s.match(/\Acfg\((.+)\)\z/)
      id = m[1] if m  and m.size == 2
    end

    id
  end

  def parse_dependencies(dependencies, project, scope, target_id = nil)
    deps = []
    #extract compile dependencies
    dependencies[:dependencies].to_a.each do |dep_id, dep_doc|
      deps << parse_dependency(dep_id, dep_doc, project, Dependency::A_SCOPE_COMPILE, target_id)
    end

    #extract development dependencies
    dependencies[:"dev-dependencies"].to_a.each do |dep_id, dep_doc|
      deps << parse_dependency(dep_id, dep_doc, project, Dependency::A_SCOPE_DEVELOPMENT, target_id)
    end

    #extract build dependencies
    dependencies[:"build-dependencies"].to_a.each do |dep_id, dep_doc|
      deps << parse_dependency(dep_id, dep_doc, project, Dependency::A_SCOPE_BUILD, target_id)
    end

    #extract test dependencies
    dependencies[:"test-dependencies"].to_a.each do |dep_id, dep_doc|
      deps << parse_dependency(dep_id, dep_doc, project, Dependency::A_SCOPE_TEST, target_id)
    end

    deps
  end

  def parse_dependency(pkg_id, version_doc, project, default_scope, target_id = nil)
    pkg_id = pkg_id.to_s.strip
    product = Product.where(
      language: Product::A_LANGUAGE_RUST,
      prod_key: pkg_id
    ).first

    dependency = init_dependency product, pkg_id
    dependency[:target] = target_id

    scope = if version_doc.is_a?(Hash)
              if version_doc.has_key?(:optional) and version_doc[:optional] == true
                Dependency::A_SCOPE_OPTIONAL
              else
                default_scope
              end
            else
              default_scope
            end
    dependency[:scope] = scope

    if version_doc.is_a?(String)
      parse_requested_version(version_doc, dependency, product)

    elsif version_doc.is_a?(Hash) and version_doc.has_key?(:version)
      version_label = version_doc[:version].to_s.strip
      parse_requested_version(version_label, dependency, product)

    elsif version_doc.is_a?(Hash) and version_doc.has_key?(:git)
      parse_requested_version(version_doc[:git], dependency, product)

    elsif version_doc.is_a?(Hash) and version_doc.has_key?(:path)
      parse_requested_version(version_doc[:path], dependency, product)
    end

    project.out_number += 1 if ProjectdependencyService.outdated?(dependency)
    project.unknown_number += 1 if product.nil?
    project.projectdependencies.push dependency

    dependency
  end

  def parse_requested_version(version, dependency, product)
    version = version.to_s.strip

    if version.empty? or ['*', 'X', 'x'].include?(version)
      log.error "#{product} version label is missing."
      dependency[:version_label] = version
      update_requested_with_current(dependency, product)
      return dependency
    end

    if product.nil?
      log.error "dependency #{dependency} has no product or its unknown"
      dependency[:version_requested] = version
      dependency[:version_label]     = version
      return dependency
    end

    if version =~ /\,/
      dependency[:version_requested]  = VersionService.from_common_range(product.versions, version, false)
      dependency[:version_label]      = version
      dependency[:comperator]         = "||"

    elsif version[0] == '='
      version_label = version.gsub(/\=\s*/, '').to_s.strip
      version_db = product.versions.where(version: version_label).first
      unless version_db
        log.error "#{product} has no match for #{version_label}"
        update_requested_with_current(dependency, product)
        return dependency
      end

      dependency[:version_requested]   = version_label
      dependency[:version_label]       = version_label
      dependency[:comperator]          = '='

    elsif version =~ /\A<(?!\=)/
      version_label = version.gsub(/<\s*/, '').to_s.strip
      newest_version = VersionService.smaller_than(product.versions, version_label)
      dependency[:version_requested]  = newest_version.to_s
      dependency[:version_label]      = version_label
      dependency[:comperator]         = '<'

    elsif version =~ /\A<=/
      version_label = version.gsub(/<=\s*/, '').to_s.strip
      newest_version = VersionService.smaller_than_or_equal(product.versions, version_label)
      dependency[:version_requested]  = newest_version.to_s
      dependency[:version_label]      = version_label
      dependency[:comperator]         = '<='

    elsif version =~ /^(>=)/
      version_label = version.gsub(/>=\s*/, '').to_s.strip
      newest_version = VersionService.greater_than_or_equal(product.versions, version_label)
      dependency[:version_requested]  = newest_version.to_s
      dependency[:version_label]      = version_label
      dependency[:comperator]         = '>='

    elsif version =~ /\A>(?!\=)/
      version_label = version.gsub(/\>\s*/, '').to_s.strip
      newest_version = VersionService.greater_than(product.versions, version_label)
      dependency[:version_requested]  = newest_version.to_s
      dependency[:version_label]      = version_label
      dependency[:comperator]         = '>'

    elsif version[0] == '^' or is_semver(version)
      version_label = version.gsub(/\^\s*/, '').to_s.strip
      dependency[:version_requested]  = VersionService.newest_caret_version(product.versions, version_label)
      dependency[:version_label]      = version_label
      dependency[:comperator]         = '^'

    elsif version[0] == '~'
      version_label = version.gsub(/\~\s*/, '').to_s.strip
      dependency[:version_requested]  = newest_tilde_version(product.versions, version_label)
      dependency[:version_label]      = version_label
      dependency[:comperator]         = '~'

    elsif version =~ /\.[\*|x|X]/
      dependency[:version_requested] = VersionService.newest_version_from_wildcard(product.versions, version)
      dependency[:version_label]      = version
      dependency[:comperator]         = '*'

    elsif version =~ /\Agit:/i or version =~ /\Ahttps?:/i
      dependency[:version_requested]  = 'GIT'
      dependency[:version_label]      = 'GIT'
      dependency[:comperator]         = '='

    elsif version.is_a?(String) and is_semver(version) == false
      dependency[:version_requested]  = 'PATH'
      dependency[:version_label]      = 'PATH'
      dependency[:comperator]         = '='
    end

    dependency
  end

  def is_semver(version_label)
    !SemVer.parse(version_label.to_s).nil?
  end

  def newest_tilde_version(versions, version_label)
    lower_border = tilde_lower_border version_label
    upper_border = tilde_upper_border version_label

    if lower_border.nil? or upper_border.nil?
      return version_label
    end

    greater_than = VersionService.greater_than_or_equal versions, lower_border, true
    newest_version = VersionService.smaller_than(greater_than, upper_border)
    if newest_version
      newest_version
    else
      version_label
    end
  end

  # finds the lower version for tilde selector
  # returns:
  #   nil - failed to parse semver
  #   string - lower border of tilde selector
  def tilde_lower_border(version_label)
    lower_ver =  SemVer.parse version_label
    return nil if lower_ver.nil?

    #remove metdata details
    lower_ver.metadata = nil
    lower_ver.prerelease = nil

    lower_ver.to_s
  end

  # finds the upper version of the tilde selector
  # it allows only changes in patch => has at least major, minor part
  # it allows only changes in minor => has only major part
  # returns:
  #   nil - failed to parse semver
  #   string - upper border of tilde selector
  def tilde_upper_border(version_label)
    upper_ver = SemVer.parse version_label
    return nil if upper_ver.nil?

    #remove metadata and prerelease details
    upper_ver.metadata = nil
    upper_ver.prerelease = nil

    if version_label =~ /^\d+\.\d+/
      upper_ver.minor += 1
      upper_ver.patch = 0
    else
      upper_ver.major += 1
      upper_ver.minor = 0
      upper_ver.patch = 0
    end

    upper_ver.to_s
  end

  def init_project(project_doc)
    Project.new(
      project_type: Project::A_TYPE_CARGO,
      language: Product::A_LANGUAGE_RUST,
      name: project_doc[:package][:name],
      version: project_doc[:package][:version]
    )
  end

  def init_dependency(product, pkg_id)
    dep = Projectdependency.new(
      name: pkg_id,
      language: Product::A_LANGUAGE_RUST
    )

    if product
      dep[:language] = product[:language]
      dep[:prod_key] = product[:prod_key]
      dep[:version_current] = product[:version]
    end

    dep
  end
end
