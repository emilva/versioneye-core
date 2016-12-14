class ProjectdependencyService < Versioneye::Service

  require 'naturalsorter'

  A_SECONDS_PER_DAY = 24 * 60 * 60 # 24h * 60min * 60s = 86400

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
  end


  def self.update_licenses_security project
    project.update_attribute(:sv_count, 0)
    project.update_attribute(:sv_count_sum, 0)
    pcount1 = Projectdependency.where(:project_id => project.id).count
    project.projectdependencies.each do |dep|
      product = dep.find_or_init_product
      update_licenses_for project, dep, product, false
      update_security_for project, dep, product, false
      dep.save
    end
    project.sv_count = project.sv_count - project.muted_svs.keys.count
    project.save
    pcount2 = Projectdependency.where(:project_id => project.id).count
    if pcount2 > pcount1 && pcount2 > project.projectdependencies.count
      project.reload
      update_licenses_security( project )
    end
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


  def self.outdated?( projectdependency )
    return nil if projectdependency.nil?

    return update_outdated!(projectdependency) if projectdependency.outdated.nil?

    last_update_ago = DateTime.now.to_i - projectdependency.outdated_updated_at.to_i
    return projectdependency.outdated if last_update_ago < A_SECONDS_PER_DAY

    update_outdated!( projectdependency )
  end

  def self.sha?(txt)
    ( txt.to_s.strip.match(/\w{40}/i) != nil )
  end

  def self.semver?(txt)
    not SemVer.parse(txt).nil?
  end

  def self.update_outdated!( projectdependency )
    update_version_current( projectdependency )

    if ( projectdependency.prod_key.nil? && projectdependency.version_current.nil? ) ||
       ( projectdependency.version_requested.eql?( 'GIT' ) || projectdependency.version_requested.eql?('PATH') ) ||
       ( projectdependency.muted == true ) ||
       ( projectdependency.version_requested.eql?( projectdependency.version_current) ) ||
       ( !projectdependency.ext_link.to_s.empty? )
      return update_outdated( projectdependency, false )
    end

    outdated = false

    #handle GO-DEP versions differently
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
      projectdependency.version_current = projectdependency.version_requested
      return false
    end

    product = projectdependency.product
    return false if product.nil?

    newest_version = VersionService.newest_version_number( product.versions, projectdependency.stability )
    return false if newest_version.nil? || newest_version.empty?

    version_current = projectdependency.version_current
    if version_current.to_s.empty? || !version_current.eql?( newest_version )
      projectdependency.version_current = newest_version
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

          licenseCach = LicenseCach.new({:name => license.name_substitute, :url => license.link} )
          licenseCach.license_id = license.id.to_s

          if project.license_whitelist
            licenseCach.on_whitelist = project.license_whitelist.include_license_substitute?( license.name_substitute )
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
        dependency.save
      elsif project.component_whitelist && project.component_whitelist.is_on_list?( dependency.cwl_key )
        licenseCach = LicenseCach.new({:name => "N/A", :on_cwl => true} )
        dependency.license_caches.push licenseCach
        dependency.lwl_violation = nil
        licenseCach.save
      end
    end


end
