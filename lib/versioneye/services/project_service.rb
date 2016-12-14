class ProjectService < Versioneye::Service


  def self.type_by_filename filename
    return nil if filename.to_s.empty?
    return nil if filename.to_s.match(/\/node_modules\//) # Skip workirectory of NPM.
    return nil if filename.to_s.casecmp('CMakeLists.txt') == 0
    return nil if filename.to_s.casecmp('robots.txt') == 0
    return nil if filename.to_s.match(/robots.txt\z/i)
    return nil if filename.to_s.match(/LICENSE.txt\z/i)
    return nil if filename.to_s.match(/README.txt\z/i)
    return nil if filename.to_s.match(/content.txt\z/i)
    return nil if filename.to_s.match(/curl.txt\z/i)
    return nil if filename.to_s.match(/comment.txt\z/i)
    return nil if filename.to_s.match(/new_file.txt\z/i)

    trimmed_name = filename.split('?')[0]
    return Project::A_TYPE_RUBYGEMS  if (!(/Gemfile\z/ =~ trimmed_name).nil?)        or (!(/Gemfile.lock\z/  =~ trimmed_name).nil?) or (/\w\.gemspec\z/ =~ trimmed_name)
    return Project::A_TYPE_COMPOSER  if (!(/composer.json\z/ =~ trimmed_name).nil?)  or (!(/composer.lock\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_PIP       if (!(/requirements.txt\z/ =~ trimmed_name).nil?) or (!(/requirements\/.+\.txt/i =~ trimmed_name).nil?) or (!(/setup.py\z/ =~ trimmed_name).nil?) or (!(/pip.log\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_NPM       if (!(/package.json\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_GRADLE    if (!(/.gradle\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_SBT       if (!(/.sbt\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_MAVEN2    if (!(/pom.xml\z/ =~ trimmed_name).nil?) or (!(/.pom\z/ =~ trimmed_name).nil?) or (!(/external_dependencies.xml\z/ =~ trimmed_name).nil?) or (!(/external-dependencies.xml\z/ =~ trimmed_name).nil?) or (!(/pom.json\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_LEIN      if (!(/project.clj\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_BOWER     if (!(/bower.json\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_BIICODE   if (!(/biicode.conf\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_COCOAPODS if (!(/Podfile\z/ =~ trimmed_name).nil?)  or (!(/.podfile\z/ =~ trimmed_name).nil?) or (!(/Podfile.lock\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_CHEF      if (!(/Berksfile.lock\z/ =~ trimmed_name).nil?)  or (!(/Berksfile\z/ =~ trimmed_name).nil?) or (!(/metadata.rb\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_NUGET     if (!(/project\.json\z/ =~ trimmed_name).nil?) or (!(/.*\.nuspec\z/ =~ trimmed_name).nil?)  or (!(/packages\.config\z/ =~ trimmed_name).nil?)
    return Project::A_TYPE_CPAN      if (/\Acpanfile\z/i =~ trimmed_name) != nil
    return nil
  end


  def self.corresponding_file filename
    return nil if filename.to_s.empty?
    trimmed_name = filename.split('?')[0]
    return 'Gemfile.lock'   if (/Gemfile\z/       =~ trimmed_name) == 0
    return 'composer.lock'  if (/composer.json\z/ =~ trimmed_name) == 0
    return 'Podfile.lock'   if (/Podfile\z/       =~ trimmed_name) == 0
    return 'Berksfile.lock' if (/metadata.rb\z/   =~ trimmed_name) == 0
    return 'Berksfile.lock' if (/Berksfile\z/     =~ trimmed_name) == 0
    return nil
  end


  def self.index( user, filter = {}, sort = nil)
    filter_options            = {:parent_id => nil, :temp => false}
    filter_options[:team_ids] = filter[:team]       if filter[:team]     && filter[:team].to_s.casecmp('ALL') != 0
    filter_options[:language] = filter[:language]   if filter[:language] && filter[:language].to_s.casecmp('ALL') != 0
    filter_options[:version]  = filter[:version]    if filter[:version]  && filter[:version].to_s.casecmp('ALL') != 0
    filter_options[:name]     = /#{filter[:name]}/i if filter[:name]     && !filter[:name].to_s.strip.empty?
    if filter[:scope].to_s == 'all_public'
      filter_options[:public] = true
    elsif filter[:scope].to_s == 'all' && user.admin == true
      # Do nothing. Admin can see ALL projects
    else
      organisation = nil
      if filter[:organisation] && !filter[:organisation].to_s.strip.empty?
        organisation = Organisation.find filter[:organisation].to_s
        organisation = Organisation.where(:name => filter[:organisation].to_s).first if organisation.nil?
      end
      member_of_orga = OrganisationService.member?( organisation, user )
      if organisation && ( member_of_orga || user.admin == true )
        filter_options[:organisation_id] = organisation.ids
      else
        filter_options[:organisation_id] = OrganisationService.index( user ).collect(&:ids).join(',')
      end
    end

    case sort
    when 'out_dated'
      Project.where( filter_options ).desc(:out_number_sum).asc(:name_downcase)
    when 'license_violations'
      Project.where( filter_options ).desc(:licenses_red_sum).asc(:name_downcase)
    else
      Project.where( filter_options ).asc(:name_downcase).desc(:licenses_red_sum)
    end
  end


  def self.all_projects( user )
    projects = {}
    projects[user.fullname] = user.projects.parents.where(:organisation_id => nil).any_of({ :temp => false }, { :temp => nil } )
    orgas = OrganisationService.index( user )
    return projects if orgas.to_a.empty?

    orgas.each do |orga|
      teams = orga.teams_by user
      next if teams.to_a.empty?

      teams.each do |team|
        projs = orga.projects.parents.where(:team_ids => team.ids).any_of({ :temp => false }, { :temp => nil } )
        next if projs.to_a.empty?

        projects["#{orga.name}/#{team.name}"] = projs
      end
    end
    projects
  end


  def self.find id
    Project.find_by_id( id )
  rescue => e
    log.error e.message
    nil
  end


  def self.find_child parent_id, child_id
    Project.where( :id => child_id, :parent_id => parent_id ).first
  rescue => e
    log.error e.message
    nil
  end


  def self.summary project_id
    map = {}
    project = find project_id
    summary_single project, map
    project.children.each do |child|
      summary_single child, map
    end
    Hash[map.sort_by {|dep| -dep.last[:dependencies].count}]
  end


  def self.summary_single project, map = {}
    name = project.filename
    name = project.name if name.to_s.empty?
    map[project.ids] = {:id => project.ids,
      :name => name,
      :dep_number => project.dep_number,
      :dep_number_sum => project.dep_number,
      :out_number => project.out_number,
      :out_number_sum => project.out_number,
      :unknown_number => project.unknown_number,
      :unknown_number_sum => project.unknown_number,
      :muted_dependencies_count => project.muted_dependencies_count,
      :licenses_red => project.licenses_red,
      :licenses_red_sum => project.licenses_red_sum,
      :licenses_unknown => project.licenses_unknown,
      :licenses_unknown_sum => project.licenses_unknown_sum,
      :sv_count => project.sv_count,
      :sv_count_sum => project.sv_count_sum,
      :dependencies => [],
      :licenses => [],
      :sv => [] }

    Projectdependency.any_of(
      {:project_id => project.ids, :outdated => true},
      {:project_id => project.ids, :prod_key => nil} ).each do |dep|
      map[project.ids][:dependencies].push dep
    end

    Projectdependency.any_of(
      {:project_id => project.ids, :lwl_violation => 'true'},
      {:project_id => project.ids, :license_caches => nil},
      {:project_id => project.ids, :license_caches.with_size => 0} ).each do |dep|
      map[project.ids][:licenses].push dep
    end

    fill_sv project, map

    map
  end


  def self.store project
    raise "project is nil." if project.nil?

    ensure_unique_ga( project )
    ensure_unique_scm( project )

    if project.save
      project.save_dependencies
      update_license_numbers!( project )
      ProjectdependencyService.update_security project
      SyncService.sync_project_async project # For Enterprise environment only!
    else
      err_msg = "Can't save project: #{project.errors.full_messages.to_json}"
      log.error err_msg
      raise err_msg
    end
    project
  end


  def self.remove_temp_projects
    Project.where(:temp => true, :temp_lock => false).delete_all
  end


  def self.ensure_unique_ga project
    return true if Settings.instance.projects_unique_ga == false
    return true if project.group_id.to_s.empty? && project.artifact_id.to_s.empty?

    project = Project.find_by_ga( project.group_id, project.artifact_id )
    return true if project.nil?

    err_msg = "A project with same GroupId and ArtifactId exist already. Project ID: #{project.id.to_s}"
    log.error err_msg
    raise err_msg
  end


  def self.ensure_unique_gav project
    return true if Settings.instance.projects_unique_gav == false
    return true if project.group_id.to_s.empty? && project.artifact_id.to_s.empty? && project.version.to_s.empty?

    db_projects = Project.where(:group_id => project.group_id, :artifact_id => project.artifact_id, :version => project.version )
    return true if db_projects.nil? || db_projects.empty?

    db_project = db_projects.first
    return true if db_project.ids.eql?( project.ids ) && db_projects.count == 1

    destroy project

    log.error "A project with same GroupId, ArtifactId and Version exist already. Project ID: #{db_project.id.to_s}. GroupId: #{db_project.group_id}, ArtifactId: #{db_project.artifact_id}, Version: #{db_project.version}"
    raise "A project with same GroupId, ArtifactId and Version exist already. Project ID: #{db_project.id.to_s}."
  end


  def self.ensure_unique_scm project
    return true if Settings.instance.projects_unique_scm == false
    return true if project.scm_fullname.to_s.empty?

    db_projects = Project.where(:source => project.source, :scm_fullname => project.scm_fullname, :scm_branch => project.scm_branch, :s3_filename => project.s3_filename)
    return true if db_projects.nil? || db_projects.empty?

    db_project = db_projects.first
    return true if db_project.ids.eql?( project.ids ) && db_projects.count == 1

    destroy project # Delete new created proejct to prevent duplicates in the database!

    log.error "The project file is already monitored by VersionEye. Project ID: #{db_project.id.to_s}. scm_fullname: #{db_project.scm_fullname}, scm_branch: #{db_project.scm_branch}, filename: #{db_project.s3_filename}"
    raise     "The project file is already monitored by VersionEye. Project ID: #{db_project.id.to_s}."
  end


  def self.merge_by_ga group_id, artifact_id, subproject_id, user_id
    user = User.find user_id
    parent = Project.find_by_ga( group_id, artifact_id )
    raise "User does not have permission to merge." if !parent.is_collaborator?( user )

    resp = merge( parent.id.to_s, subproject_id, user_id )
    update_sums parent
    resp
  end


  def self.merge project_id, subproject_id, user_id
    project    = find project_id
    subproject = find subproject_id
    return false if project.nil? || subproject.nil?
    return false if subproject.parent_id        # subproject has already a parent project!
    return false if project.parent_id           # project is already a subproject!
    return false if !subproject.children.empty? # subproject is a parent project!
    return false if project.id.to_s.eql?(subproject.id.to_s) # project & subproject are the same!

    user = User.find user_id
    return false if user.nil?

    if !project.is_collaborator?(user)
      raise "User has no permission to merge this project!"
    end

    subproject.parent_id = project.id
    subproject.license_whitelist_id = project.license_whitelist_id
    subproject.component_whitelist_id = project.component_whitelist_id
    subproject.save

    update_sums( project )

    reset_badge project
    reset_badge subproject

    ProjectUpdateService.update_async project
    true
  end


  def self.unmerge project_id, subproject_id, user_id
    project    = find project_id
    subproject = Project.where( :id => subproject_id, :parent_id => project_id ).first
    return false if project.nil? || subproject.nil?

    user = User.find user_id
    return false if user.nil?

    if !project.is_collaborator?(user)
      raise "User has no permission to unmerge this project!"
    end

    subproject.parent_id = nil
    subproject.save

    reset_badge project
    reset_badge subproject

    ProjectUpdateService.update_async project
    ProjectUpdateService.update_async subproject
    true
  end


  def self.destroy_by user, project_id
    project = Project.find_by_id( project_id )
    return false if project.nil?

    if project.is_collaborator?( user ) || user.admin == true
      destroy project
    else
      raise "User has no permission to delete this project!"
    end
  end


  def self.destroy project
    return false if project.nil?

    project.children.each do |child_project|
      destroy_single child_project.id
    end
    parent = project.parent
    destroy_single project.id
    update_sums parent
    return true
  end


  def self.destroy_single project_id
    project = Project.find_by_id( project_id )
    return false if project.nil?

    project.remove_dependencies
    project.remove
  end


  # Returns a map with
  #  - :key => "language_prod_key"
  #  - :value => "Array of project IDs where the prod_key is used"
  def self.user_product_index_map user, add_collaborated = true
    indexes = Hash.new
    projects = user.projects
    if projects
      project_prod_index projects, indexes
    end
    return indexes if add_collaborated == false

    collaborated_projects = []
    orgas = OrganisationService.index( user )
    orgas.each do |orga|
      orga.projects.each do |project|
        collaborated_projects << project if project.is_collaborator?( user )
      end
    end
    project_prod_index collaborated_projects, indexes

    indexes
  end

  def self.project_prod_index projects, indexes
    projects.each do |project|
      next if project.nil?

      project.dependencies.each do |dep|
        next if dep.nil? or dep.product.nil?

        product = dep.product
        prod_id = "#{product.language_esc}_#{product.prod_key}"
        indexes[prod_id] = [] unless indexes.has_key?(prod_id)
        indexes[prod_id] << {:project_id => project[:_id].to_s, :version_requested => dep.version_requested}
      end
    end
    indexes
  end


  def self.insecure?( project )
    return true if insecure_single?( project )

    project.children.each do |child_project|
      return true if insecure_single?( child_project )
    end
    false
  end


  def self.insecure_single?( project )
    return false if project.language.eql?(Product::A_LANGUAGE_PHP) && !project.filename.eql?('composer.lock')

    project.sv_count > 0
  end


  def self.outdated?( project )
    return true if outdated_single?( project )
    project.children.each do |child_project|
      return true if outdated_single?( child_project )
    end
    false
  end

  def self.outdated_single?( project )
    project.projectdependencies.each do |dep|
      next if dep.scope.to_s.eql?(Dependency::A_SCOPE_DEVELOPMENT)
      next if dep.scope.to_s.eql?(Dependency::A_SCOPE_TEST)
      return true if ProjectdependencyService.outdated?( dep )
    end
    false
  end


  def self.outdated_dependencies( project, force_update = false )
    outdated_dependencies = Array.new
    project.projectdependencies.each do |dep|
      ProjectdependencyService.update_outdated!( dep ) if force_update
      outdated_dependencies << dep if ProjectdependencyService.outdated?( dep )
    end
    outdated_dependencies
  end


  # Returns the projectdependencies which have unknown licenses
  def self.unknown_licenses( project )
    unknown = Array.new
    return unknown if project.nil? || project.projectdependencies.empty?

    project.projectdependencies.each do |dep|
      product = dep.product
      if product.nil?
        unknown << dep
        next
      end
      product.version = dep.version_requested
      unknown << dep if product.licenses.nil? || product.licenses.empty?
    end
    unknown
  end

  # Returns the projectdependencies which violate the
  # license whitelist AND are not on the component whitelist
  def self.red_licenses( project )
    red = []
    return red if project.nil? || project.projectdependencies.empty? || project.license_whitelist_id.nil?

    whitelist = project.license_whitelist
    return red if whitelist.nil?
    return red if whitelist.license_elements.nil? || whitelist.license_elements.empty?

    project.projectdependencies.each do |dep|
      license_caches = dep.license_caches
      next if license_caches.nil? || license_caches.empty?

      red << dep if whitelisted?( license_caches, whitelist ) == false
    end
    red
  end


  def self.update_license_numbers!( project )
    return nil if project.nil? || project.projectdependencies.empty?

    ProjectdependencyService.update_licenses_security project
    project.licenses_unknown = unknown_licenses( project ).count
    project.licenses_red = red_licenses( project ).count
    project.save
  end


  def self.update_sums( project )
    return if project.nil?

    children = project.children
    if children.empty?
      project.sum_own!
      reset_badge project
      return nil
    end

    dep_hash = {}
    project.sum_reset!
    children.each do |child_project|
      update_numbers_for project, child_project, dep_hash
      child_project.sum_own!
    end
    update_numbers_for project, project, dep_hash
    project.child_count = children.count
    project.save
    reset_badge project
    project
  end


  def self.reset_badge project
    reset_badge_for project.ids
  end

  def self.reset_badge_for project_id
    cache.delete( project_id )
    cache.delete( "#{project_id}__flat" )
    cache.delete( "#{project_id}__flat-square" )
    cache.delete( "#{project_id}__plastic" )
    Badge.where( :key => project_id ).delete
    Badge.where( :key => "#{project_id}__flat" ).delete
    Badge.where( :key => "#{project_id}__flat-square" ).delete
    Badge.where( :key => "#{project_id}__plastic" ).delete
  end


  private

    # TODO optimize this by only loading affected deps.
    def self.fill_sv project, map
      # id = Moped::BSON::ObjectId.from_string(project.ids)
      # id = project.ids
      # deps = Projectdependency.collection.find(:project_id => id, 'sv_ids' => {'$not' => {'$size' => 0} } )
      deps = Projectdependency.where(:project_id => project.ids )
      deps.each do |dep|
        map[project.ids][:sv].push dep if !dep.sv_ids.empty?
      end
    rescue => e
      log.error e.message
      log.error e.backtrace.join("\n")
    end


    def self.update_numbers_for project, child_project, dep_hash = {}
      lwl = project.license_whitelist
      child_project.projectdependencies.each do |dep|
        key = "#{dep.language}:#{dep.possible_prod_key}:#{dep.version_requested}"
        next if dep_hash.include? key

        product = dep.product
        product.version = dep.version_requested if !product.nil?
        dep_hash[key] = dep
        project.dep_number_sum       += 1
        project.out_number_sum       += 1 if dep.outdated
        project.unknown_number_sum   += 1 if dep.unknown?
        project.licenses_unknown_sum += 1 if product.nil? || product.licenses.nil? || product.licenses.empty?
        if lwl && red_license?( dep, lwl )
          project.licenses_red_sum += 1
        end
        project.sv_count_sum += dep.sv_ids.count if !dep.sv_ids.empty?
      end
      dep_hash
    end


    def self.red_license? projectdependency, whitelist
      lcs = projectdependency.license_caches
      return false if lcs.nil? || lcs.empty? || whitelist.nil?

      if whitelist.pessimistic_mode == true
        lcs.each do |lc|
          return true if lc.is_whitelisted? == false
        end
        return false
      else
        lcs.each do |lc|
          return false if lc.is_whitelisted? == true
        end
        return true
      end
    end


    def self.whitelisted? license_caches, whitelist
      return nil if whitelist.nil?

      if whitelist.pessimistic_mode == true
        license_caches.each do |lc|
          return false if lc.is_whitelisted? == false
        end
        return true
      else
        license_caches.each do |lc|
          return true if lc.is_whitelisted? == true
        end
        return false
      end
    end


end
