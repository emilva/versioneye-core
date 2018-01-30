class ProjectdependencyService < Versioneye::Service

  require 'naturalsorter'
  extend Comperators::Github

  A_SECONDS_PER_DAY = 24 * 60 * 60 # 24h * 60min * 60s = 86400


  def self.create_transitive_deps( project )
    deepness = 0
    uniq_map = Hash.new
    project.dependencies.each do |dep|
      create_transitive_dep( project, dep, deepness, uniq_map )
    end
    uniq_map
  end

  def self.create_transitive_dep( project, dep, deepness = 0, uniq_map = Hash.new)
    ukey = "#{dep.language}:#{dep.prod_key}:#{dep.version_requested}"
    return nil if uniq_map.keys.include?( ukey )

    uniq_map[ukey] = dep
    product = dep.product
    return nil if product.nil?

    product.version = dep.version_requested
    prod_deps = product.all_dependencies( dep.version_requested )
    return nil if prod_deps.empty?

    prod_deps.each do |prod_dep|
      DependencyService.update_parsed_version( prod_dep )
      prod_dep.save
      project_dep = Projectdependency.where(
          :project_id => project.ids,
          :language => prod_dep.language,
          :prod_key => prod_dep.dep_prod_key,
          :version_requested => prod_dep.parsed_version
      ).first

      if project_dep
        create_transitive_dep( project, project_dep, deepness.to_i + 1, uniq_map )
        next
      end

      project_dep = Projectdependency.new({
          :project_id => project.ids,
          :language => prod_dep.language,
          :prod_key => prod_dep.dep_prod_key,
          :version_requested => prod_dep.parsed_version,
          :deepness => deepness.to_i + 1
      })
      project_dep.name            = prod_dep.name
      project_dep.group_id        = prod_dep.group_id
      project_dep.artifact_id     = prod_dep.artifact_id
      project_dep.scope           = prod_dep.scope
      project_dep.version_current = prod_dep.current_version.to_s.gsub(/-redhat-.*/i, "")
      project_dep.version_label   = prod_dep.parsed_version.to_s.gsub(/-redhat-.*/i, "")
      project_dep.transitive      = true
      project_dep.parent_prod_key = dep.prod_key
      project_dep.parent_version  = dep.version_requested
      project_dep.parent_id       = dep.id
      project_dep.save

      tt = ""
      deepness.times do |ds|
        tt += " "
      end
      p "#{tt} - #{project_dep.prod_key}:#{project_dep.version_requested} - #{project_dep.deepness}"

      update_licenses_for project, project_dep, project_dep.product
      update_security_for project, project_dep, project_dep.product

      create_transitive_dep( project, project_dep, deepness.to_i + 1, uniq_map )
    end
    uniq_map
  end


  # Updates projectdependency.license_caches for each projectdependency of the project
  def self.update_licenses project
    project.projectdependencies.each do |dep|
      product = dep.find_or_init_product
      update_licenses_for project, dep, product
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join "\n"
  end


  def self.update_licenses_for project, dep, product, save_dep = true
    dep.license_caches.clear
    dep.lwl_violation = nil
    product.version = dep.version_requested
    fill_license_cache project, dep, product.licenses
    dep.save if save_dep
  rescue => e
    log.error e.message
    log.error e.backtrace.join "\n"
  end


  # Updates projectdependency.sv_ids for each projectdependency of the project
  def self.update_security project
    project.sv_count = 0
    project.update_attribute(:sv_count, 0)
    project.update_attribute(:sv_count_sum, 0)
    project.projectdependencies.each do |dep|
      product = dep.find_or_init_product
      update_security_for project, dep, product
    end
    project.sv_count = project.sv_count - project.muted_svs.keys.count
    project.save
  rescue => e
    log.error e.message
    log.error e.backtrace.join "\n"
  end


  def self.update_security_for project, dep, product, save_dep = true
    version = product.version_by_number dep.version_requested
    return nil if version.nil?
    return nil if version.sv_ids.to_a.empty?

    dep.sv_ids = []
    nsps = []
    version.sv_ids.each do |sv_id|
      sv = SecurityVulnerability.find sv_id
      if sv.nil?
        version.sv_ids.delete sv_id
        version.save
        next
      end
      if !dep.sv_ids.include?(sv_id) && !nsps.include?( sv.nsp )
        dep.sv_ids << sv_id
        nsps       << sv.nsp if !sv.nsp.to_s.empty?
      end
      dep.save if save_dep
    end

    new_count = project.sv_count + dep.sv_ids.size
    project.sv_count = new_count
    project.update_attribute(:sv_count, new_count)
  rescue => e
    log.error e.message
    log.error e.backtrace.join "\n"
  end


  def self.update_licenses_security project
    return nil if project.nil?

    log.info "start update_licenses_security for #{project.ids}"
    project.update_attribute(:sv_count, 0)
    project.update_attribute(:sv_count_sum, 0)
    pcount1 = Projectdependency.where(:project_id => project.id).count
    project.projectdependencies.each do |dep|
      product = dep.find_or_init_product
      update_licenses_for project, dep, product, true
      update_security_for project, dep, product, true
      dep.save
    end
    project.sv_count = project.sv_count - project.muted_svs.keys.count
    project.save
    pcount2 = Projectdependency.where(:project_id => project.id).count
    if pcount2 > pcount1 && pcount2 > project.projectdependencies.count
      project.reload
      update_licenses_security( project )
    end
    log.info "finish update_licenses_security for #{project.ids}"
    project
  rescue => e
    log.error e.message
    log.error e.backtrace.join "\n"
  end


  def self.mute! project_id, dependency_id, mute_status, mute_message = nil
    project = Project.find_by_id( project_id )
    return false if project.nil?

    dependency = Projectdependency.find_by_id dependency_id
    return false if dependency.nil?
    return false if !dependency.project_id.to_s.eql? project_id
    return false if dependency.project.nil?

    dependency.muted = mute_status
    if mute_status == true
      dependency.outdated = false
      dependency.outdated_updated_at = DateTime.now
      dependency.mute_message = mute_message
    else
      update_outdated! dependency
    end
    update_project_numbers dependency, project
    saved = dependency.save
    up = project
    up = project.parent if project.parent_id
    ProjectService.update_sums up
    ProjectService.reset_badge up
    saved
  end


  def self.release?( projectdependency )
    return nil if projectdependency.nil? || projectdependency.version_current.nil?

    projectdependency.release = VersionTagRecognizer.release? projectdependency.version_current
    projectdependency.save
    projectdependency.release
  end


  def self.outdated?( projectdependency, product = nil, auth_token = nil)
    return nil if projectdependency.nil?

    if projectdependency.outdated.nil?
      log.info "outdated? - checking new dependency #{projectdependency}"
      return update_outdated!(projectdependency, product, auth_token)
    end

    last_update_ago = DateTime.now.to_i - projectdependency.outdated_updated_at.to_i
    return projectdependency.outdated if last_update_ago < A_SECONDS_PER_DAY

    update_outdated!( projectdependency, product, auth_token )
  end

  #TODO: shas can only include HEX (0-9A-F), mostly 40chars, but maybe as short 7char
  def self.sha?(txt)
    ( txt.to_s.strip.match(/\w{40}/i) != nil )
  end

  def self.semver?(txt)
    not SemVer.parse(txt).nil?
  end

  def self.update_outdated!( projectdependency, product = nil, auth_token = nil)
    update_version_current( projectdependency )

    if ( projectdependency.prod_key.nil? && projectdependency.version_current.nil? ) ||
       ( projectdependency.version_requested.eql?( 'GIT' ) || projectdependency.version_requested.eql?('PATH') ) ||
       ( projectdependency.muted == true ) ||
       ( projectdependency.version_requested.eql?( projectdependency.version_current) ) ||
       ( !projectdependency.ext_link.to_s.empty? )
      return update_outdated( projectdependency, false )
    end

    outdated = false

    # checks does Projectdependency on Github is outdated or not
    if projectdependency[:version_requested] == 'GITHUB'
      is_outdated = check_github_version(projectdependency, product, auth_token)
      return update_outdated(projectdependency, is_outdated)
    end

    # Handle GO-DEP versions differently
    if projectdependency[:language] == Product::A_LANGUAGE_GO
      req_version = godep_to_semver(projectdependency)
    else
      req_version = projectdependency.version_requested
    end

    newest_version = Naturalsorter::Sorter.sort_version([
      projectdependency.version_current,
      req_version
    ]).last
    outdated = !newest_version.eql?( req_version )

    update_outdated( projectdependency, outdated )
    projectdependency.outdated
  end

  # compares latest stable release date with the commit date on Github
  #
  # expects that projectDependency models has specified additional fields:
  # repo_fullname - string, format `owner_name/repo_name`
  # repo_ref      - string, git reference to look up commit details,
  #                 can be commit_sha, tag, or branch
  #
  # returns:
  #   true - if package is out-dated
  #   false - if package is up-to-date or we failed to make request or it's unknown
  def self.check_github_version(dep, product, auth_token)
    log.info "check_github_version: going to check state of #{dep}"
    if auth_token.nil?
      log.error "check_github_version: auth_token is missing"
      return false
    end

    if dep[:repo_fullname].nil? or dep[:repo_ref].nil?
      log.error "check_github_version: :repo_fullname or :repo_ref is unspecified"
      log.error " dependency: #{dep}"
      return false
    end

    if product.nil? or product.is_a?(Product) == false
      log.error "check_github_version: no product for dep.#{dep}"
      return false
    end

    # comes from Comperators::Github
    gh_state = compare_github_version(dep[:repo_ref], dep, product.versions, auth_token)
    gh_state == Comperators::IS_OUTDATED
  end

  def self.godep_to_semver(proj_dep)
    req_version = proj_dep.version_requested
    translated_version = '0.0.0+NA' #used when couldnt find version by SHA or TAG

    the_prod = proj_dep.product
    if the_prod.nil?
      log.warn "check_godep: dependency #{proj_dep[:prod_key]} has no product attached"
      return translated_version #it doesnt mark unknown dependencies as outdated -> we have no enough info
    end

    if sha?(req_version)
      version_db = the_prod.versions.find_by(sha1: req_version)
      if version_db
        translated_version = version_db[:version]
      else
        log.warn "check_godep: found no version by sha `#{req_version}` for #{proj_dep[:prod_key]}"
      end

    elsif semver?(req_version)
      #NB: SemVer.parse doesnt work as it always adds minor as 0, but tags may not have 0 at the end
      translated_version = req_version.to_s.gsub(/\Av/i, '')
    else
      version_db = the_prod.versions.find_by(tag: req_version)
      if version_db
        translated_version = version_db[:version]
      else
        log.warn "check_godep: found no version by tag `#{req_version}` for #{proj_dep[:prod_key]}"
      end
    end

    translated_version
  end

  def self.update_outdated( projectdependency, out_value )
    projectdependency.outdated = out_value
    projectdependency.outdated_updated_at = DateTime.now
    if !projectdependency.version_current.nil?
      self.release? projectdependency
    end
    projectdependency.save
    projectdependency.outdated
  rescue => e
    log.error e.message
    log.error e.backtrace.join "\n"
    out_value
  end


  def self.update_version_current( projectdependency )
    if projectdependency.prod_key.nil?
      update_prod_key projectdependency
    end

    if !projectdependency.ext_link.to_s.empty?
      projectdependency.version_current = projectdependency.version_requested.to_s.gsub(/-redhat-.*/i, "")
      return false
    end

    product = projectdependency.product
    return false if product.nil?

    newest_version = product.dist_tags_latest
    if newest_version.to_s.empty?
      newest_version = VersionService.newest_version_number( product.versions, projectdependency.stability )
    end
    return false if newest_version.to_s.empty?

    version_current = projectdependency.version_current
    if version_current.to_s.empty? || !version_current.eql?( newest_version )
      projectdependency.version_current = newest_version.to_s.gsub(/-redhat-.*/i, "")
      projectdependency.release = VersionTagRecognizer.release? projectdependency.version_current
      projectdependency.muted = false
    end
    if projectdependency.version_requested.to_s.empty?
      projectdependency.version_requested = newest_version
    end
    if projectdependency.version_label.to_s.empty?
      projectdependency.version_label = projectdependency.version_requested
    end
    projectdependency.save()
  rescue => e
    log.error e.message
    log.error e.backtrace.join "\n"
    false
  end


  def self.update_prod_key dependency
    product = dependency.find_or_init_product
    return nil if product.nil?

    dependency.prod_key = product.prod_key
    dependency.save
  end


  def self.update_prod_keys
    Projectdependency.all.each do |dependency|
      update_prod_key dependency
    end
  end


  private


    def self.update_project_numbers dependency, project
      if dependency.outdated
        project.out_number = project.out_number.to_i + 1
        project.out_number_sum = project.out_number_sum.to_i + 1
      else
        project.out_number = project.out_number.to_i - 1
        project.out_number_sum = project.out_number_sum.to_i - 1
      end
      project.out_number = 0 if project.out_number < 0
      project.out_number_sum = 0 if project.out_number_sum < 0
      project.save
    end


    def self.fill_license_cache project, dependency, licenses
      if licenses && !licenses.empty?
        licenses.each do |license|
          next if license.nil?

          licenseCach = LicenseCach.new({:name => license.label, :url => license.link} )
          licenseCach.license_id = license.id.to_s

          if project.license_whitelist
            licenseCach.on_whitelist = project.license_whitelist.include_license_substitute?( license.label )
          end

          if project.component_whitelist
            licenseCach.on_cwl = project.component_whitelist.is_on_list?( dependency.cwl_key )
          end

          dependency.license_caches.push licenseCach
          licenseCach.save
        end # end for each loop
        dependency.lwl_violation = ProjectService.red_license?( dependency, project.license_whitelist )
        if project.license_whitelist && ProjectService.whitelisted?( dependency.license_caches, project.license_whitelist ) == false
          dependency.license_violation = true
        end
      elsif project.component_whitelist && project.component_whitelist.is_on_list?( dependency.cwl_key )
        licenseCach = LicenseCach.new({:name => "Comp. whitelist", :on_cwl => true} )
        dependency.license_caches.push licenseCach
        dependency.lwl_violation = nil
        licenseCach.save
      end
      dependency.save
    end


end
