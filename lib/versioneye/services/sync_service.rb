class SyncService < Versioneye::Service


  def self.log
    if !defined?(@@dynLog) || @@dynLog.nil?
      environment = ENV['RAILS_ENV']
      environment = 'development' if environment.to_s.empty?
      @@dynLog = Versioneye::DynLog.new("log/#{environment}_sync.log", 10).log
    end
    @@dynLog
  end


  def self.sync_disabled?
    env = Settings.instance.environment
    disable_sync = GlobalSetting.get env, 'disable_sync'
    return true if disable_sync.to_s.eql?('true')
    return false
  end


  def self.sync
    sync_projectdependencies Projectdependency.all
  end


  def self.sync_all_products skip_known_versions = true
    if sync_disabled?
      log.info "db sync is disabled!"
      return nil
    end

    log.info "START sync ALL products"
    ProductService.all_products_paged do |products|
      sync_products products, skip_known_versions
    end
    log.info "STOP sync ALL products"
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.sync_products products, skip_known_versions = true
    products.each do |product|
      sync_product product.language, product.prod_key, skip_known_versions
    end
  end


  def self.sync_project project
    if sync_disabled?
      log.info "db sync is disabled!"
      return nil
    end

    sync_status = SyncStatus.find_or_create_by( :comp_type => 'Project', :comp_id => project.ids )
    sync_status.status = 'running'
    sync_status.save

    sync_projectdependencies project.unknown_dependencies, false
    sync_projectdependencies project.known_dependencies, true

    log.info "sync lock true ... start reparse project"
    project.update_attribute(:sync_lock, true)
    ProjectUpdateService.update project
    project.update_attribute(:sync_lock, false)
    log.info "sync lock false ... sync done for project #{project.ids}"

    sync_status = SyncStatus.find_or_create_by( :comp_type => 'Project', :comp_id => project.ids )
    sync_status.status = 'done'
    sync_status.save
  end


  def self.sync_project_async project
    env = Settings.instance.environment
    return nil if !env.to_s.eql?("enterprise")
    return nil if project.sync_lock == true

    project_id = project.ids
    SyncProducer.new "project::#{project_id}"
  end


  def self.sync_projectdependencies dependencies, quicky = false
    lang_prod_keys = []
    dependencies.each do |dependency|
      lang_key = "#{dependency.language}::#{dependency.possible_prod_key}"
      next if lang_prod_keys.include?( lang_key )

      update_sync_info dependency

      if dependency.project.project_type.to_s.eql?(Project::A_TYPE_BOWER)
        sync_projectdependency_bower dependency, quicky
      else
        sync_projectdependency dependency, quicky
      end

      lang_prod_keys << lang_key
    end
    log.info "-- sync done for projectdependencies --"
  end


  def self.update_sync_info dependency
    sync_status = SyncStatus.find_or_create_by( :comp_type => 'Project', :comp_id => dependency.project.ids )
    sync_status.update_attribute(:info, dependency.name)
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.sync_projectdependency dependency, quicky = true
    if sync_disabled?
      log.info "db sync is disabled!"
      return nil
    end

    prod_key = dependency.possible_prod_key
    language = dependency.language

    if quicky
      sync_version  language, prod_key
      sync_version  language, prod_key, dependency.version_requested
      sync_security language, prod_key
    else
      sync_product language, prod_key, false
    end

    product = Product.fetch_product( dependency.language, prod_key )
    return nil if product.nil?

    dependency.prod_key = prod_key
    ProjectdependencyService.update_outdated!( dependency )
    log.info dependency.to_s
    true
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def self.sync_projectdependency_bower dependency, quicky = true
    if sync_disabled?
      log.info "db sync is disabled!"
      return nil
    end

    key      = dependency.name
    language = 'Bower'

    if quicky
      sync_version  language, key
      sync_version  language, key, dependency.version_requested
      sync_security language, key
    else
      sync_product language, key, false
    end

    product = Product.fetch_bower(key)
    return nil if product.nil?

    dependency.prod_key = dependency.possible_prod_key
    ProjectdependencyService.update_outdated!( dependency )
    log.info dependency.to_s
    true
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def self.sync_product language, prod_key, skip_known_versions = true
    if sync_disabled?
      log.info "db sync is disabled!"
      return nil
    end

    sync_product_versions language, prod_key, skip_known_versions
    sync_security language, prod_key
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def self.sync_security language, prod_key
    if sync_disabled?
      log.info "db sync is disabled!"
      return nil
    end

    json = SecurityClient.index language, prod_key
    return nil if json.nil?

    json.deep_symbolize_keys!
    if !json[:error].to_s.empty?
      log.error "Error in response from VersionEye API: #{json[:error]}"
      return nil
    end

    return nil if json[:results].to_a.empty?

    product = Product.fetch_product language, prod_key
    json[:results].each do |svjson|
      update_svobject( product, svjson )
    end

    log.info "synced security infos for #{language}:#{prod_key}"
  end


  def self.update_svobject product, svjson
    sv = SecurityVulnerability.find_or_create_by(
      {
       :language => svjson[:language],
       :prod_key => svjson[:prod_key],
       :name_id => svjson[:name_id]
      }
    )
    sv.update_from svjson
    reset_svids product, sv
  end


  def self.reset_svids product, sv
    return nil if product.nil? || sv.nil?

    product.versions.each do |version|
      version.sv_ids = []
    end
    sv.affected_versions.each do |version|
      product.add_svid version, sv
    end
    product.save
  end


  def self.sync_product_versions language, prod_key, skip_known_versions = true
    if sync_disabled?
      log.info "db sync is disabled!"
      return nil
    end

    json = ProductClient.versions language, prod_key
    return nil if json.nil?

    json.deep_symbolize_keys!
    if !json[:error].to_s.empty?
      log.error "Error in response from VersionEye API: #{json[:error]}"
      return nil
    end

    return nil if json[:versions].nil?

    product_preload = language.to_s.eql?('Bower') ? Product.fetch_bower(prod_key) : Product.fetch_product(language, prod_key)

    json[:versions].each do |ver|
      new_version = product_preload.nil? || product_preload.version_by_number(ver[:version]).nil?
      next if new_version == false && skip_known_versions == true

      product = sync_version( language, prod_key, ver[:version] )

      if product && new_version == true
        NewestService.create_newest( product, ver[:version] )
        NewestService.create_notifications(product, ver[:version])
      end
    end
    log.info "synced #{language}:#{prod_key}"
    true
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def self.sync_version language, prod_key, version = nil
    if sync_disabled?
      log.info "db sync is disabled!"
      return nil
    end

    json = ProductClient.show language, prod_key, version
    return nil if json.nil?

    json.deep_symbolize_keys!

    product = create_product_if_not_exist json

    handle_licenses json
    handle_links json
    handle_archives json
    handle_dependencies json

    product
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.create_product_if_not_exist json
    return nil if json.nil?

    language = Product.decode_language json[:language]
    product = Product.fetch_product language, json[:prod_key]
    if product
      product.add_version json[:version], {:released_at => parsed_date(json[:released_at]) }
      product.save
      ProductService.update_version_data product, true
      return product
    end

    product = Product.new
    product.language      = language
    product.prod_key      = json[:prod_key]
    product.name          = json[:name]
    product.name_downcase = product.name.to_s.downcase
    product.prod_type     = json[:prod_type]
    product.version       = json[:version]
    product.group_id      = json[:group_id]
    product.artifact_id   = json[:artifact_id]
    product.description   = json[:description]
    product.save
    product.add_version json[:version], {:released_at => parsed_date(json[:released_at]) }
    product.save
    ProductService.update_version_data product, true
    product
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.handle_licenses json
    return nil if json[:licenses].nil?

    json[:licenses].each do |license|
      license.deep_symbolize_keys!
      create_license_if_not_exist json, license[:name], license[:url]
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.create_license_if_not_exist json, name, url
    language = Product.decode_language json[:language]
    prod_key = json[:prod_key]
    version = json[:version]
    License.find_or_create language, prod_key, version, name, url
  end



  def self.handle_links json
    return nil if json[:links].nil?

    json[:links].each do |link|
      link.deep_symbolize_keys!
      create_link_if_not_exist json, link[:name], link[:link]
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.create_link_if_not_exist json, name, link
    language = Product.decode_language json[:language]
    prod_key = json[:prod_key]
    version = json[:version]
    Versionlink.create_versionlink language, prod_key, version, link, name
  end



  def self.handle_archives json
    return nil if json[:archives].nil?

    json[:archives].each do |archive|
      archive.deep_symbolize_keys!
      create_archive_if_not_exist json, archive[:name], archive[:link]
    end
  rescue => e
    log.error e.message
  end


  def self.create_archive_if_not_exist json, name, link
    language = Product.decode_language json[:language]
    prod_key = json[:prod_key]
    version  = json[:version]
    archive  = Versionarchive.new({:language => language, :prod_key => prod_key, :version_id => version, :link => link, :name => name})
    Versionarchive.create_archive_if_not_exist archive
  end


  def self.handle_dependencies json
    return nil if json[:dependencies].nil?

    json[:dependencies].each do |dependency|
      dependency.deep_symbolize_keys!
      create_dependency_if_not_exist json, dependency
    end
  rescue => e
    log.error e.message
  end


  def self.create_dependency_if_not_exist json, dependency
    language = Product.decode_language json[:language]
    prod_key = json[:prod_key]
    prod_version = json[:version]

    dep_prod_key = dependency[:dep_prod_key]
    dep_version = dependency[:version]

    dependencies = Dependency.where(language: language, prod_key: prod_key, prod_version: prod_version, dep_prod_key: dep_prod_key, version: dep_version)
    return nil if dependencies && dependencies.count > 0

    new_dep = Dependency.new({language: language, prod_key: prod_key, prod_version: prod_version, dep_prod_key: dep_prod_key, version: dep_version})
    new_dep.prod_type      = json[:prod_type]
    new_dep.scope          = dependency[:scope]
    new_dep.name           = dependency[:name]
    new_dep.group_id       = dependency[:group_id]
    new_dep.artifact_id    = dependency[:artifact_id]
    new_dep.parsed_version = dependency[:parsed_version]
    new_dep.save
    DependencyService.outdated? new_dep
  end


  private


    def self.parsed_date released_at
      return nil if released_at.to_s.empty?

      DateTime.parse( released_at )
    rescue => e
      log.error "parsed_date: failed to parse `#{released_at}`"
      log.error e.message
      log.error e.backtrace.join('\n')
      nil
    end


end
