class NewestService < Versioneye::Service


  def self.create_newest( product, version_number, logger = nil )
    newest = Newest.fetch_newest( product.language, product.prod_key, version_number )
    return nil if newest

    newest = Newest.new
    newest.name       = product.name
    newest.language   = product.language
    newest.prod_key   = product.prod_key
    newest.version    = version_number
    newest.prod_type  = product.prod_type
    newest.product_id = product._id.to_s
    newest.save
  rescue => e
    log_exception e, logger
    false
  end


  def self.create_notifications(product, version_number, logger = nil)
    new_notifications = 0
    subscribers = product.users
    return new_notifications if subscribers.nil? || subscribers.empty?

    subscribers.each do |subscriber|
      success = create_notification( subscriber, product, version_number, logger )
      new_notifications += 1 if success
    end
    new_notifications
  rescue => e
    log_exception e, logger
    false
  end

  def self.create_notification user, product, version_number, logger
    notification            = Notification.new
    notification.user       = user
    notification.product    = product
    notification.version_id = version_number
    notification.save
  rescue => e
    log_exception e, logger
    false
  end



  def self.run_worker
    loop do
      post_process
      update_nils
      multi_log "sleep for a while"
      sleep 60
    end
  end


  def self.update_nils
    Dependency.where( :known => true, :version.ne => nil ).any_of( {:parsed_version => nil}, {:current_version => nil} ).each do |dep|
      DependencyService.update_parsed_version dep, dep.product
      DependencyService.outdated? dep, true
      multi_log "NewestService.update_nils #{dep.ids} #{dep.dep_prod_key} : #{dep.version} : #{dep.parsed_version} : #{dep.current_version}"
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.post_process
    newests = Newest.any_of( {:processed => false}, {:processed => nil} )
    newests.each do |newest|
      process newest
    end
  end


  def self.process newest
    product = newest.product
    return nil if product.nil?

    multi_log "---"
    multi_log "ProductService.update_meta_data for #{product.language}:#{product.prod_key}"
    ProductService.update_meta_data product, false

    multi_log "NewestService.update_dependencies for #{product.language}:#{product.prod_key}"
    update_dependencies product, newest.version

    multi_log "NewestService.update_projectdependencies for #{product.language}:#{product.prod_key}"
    update_projectdependencies product, newest.version

    newest.processed = true
    newest.save
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.update_dependencies product, version
    if !product.group_id.to_s.empty? && !product.artifact_id.to_s.empty?
      update_current_version_maven product
      update_outdated_maven( product )
    else
      update_current_version( product )
      update_outdated( product )
    end
    multi_log "update product dependencies for #{product.language}:#{product.prod_key}:#{version}"
    DependencyService.update_dependencies product, version
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.update_current_version_maven product
    multi_log "update_current_version_maven for #{product.language}:#{product.prod_key}"
    Dependency.where(
      :group_id => product.group_id,
      :artifact_id => product.artifact_id
      ).update_all(:current_version => product.version)
  end


  def self.update_current_version product
    multi_log "update_current_version for #{product.language}:#{product.prod_key}"
    Dependency.where(
      :language => product.language,
      :dep_prod_key => product.prod_key
      ).update_all(:current_version => product.version)
  end


  def self.update_outdated_maven product
    multi_log "update_outdated_maven for #{product.language}:#{product.prod_key}"
    dependencies = Dependency.where(
      :group_id => product.group_id,
      :artifact_id => product.artifact_id)
    dependencies.each do |dependency|
      DependencyService.soft_outdated?( dependency, product )
    end
  end


  def self.update_outdated product
    multi_log "update_outdated for #{product.language}:#{product.prod_key}"
    dependencies = Dependency.where(
      :language => product.language,
      :dep_prod_key => product.prod_key)
    dependencies.each do |dependency|
      DependencyService.soft_outdated?( dependency, product )
    end
  end


  def self.update_projectdependencies product, version
    if !product.group_id.to_s.empty? && !product.artifact_id.to_s.empty?
      update_current_version_maven_pd product
      update_outdated_maven_pd( product )
    else
      update_current_for_pd product
      update_outdated_pd product
    end
  end

  def self.update_current_version_maven_pd product
    multi_log "update_current_version_maven for #{product.language}:#{product.prod_key}"
    newest_version = product.version.to_s.gsub(/-redhat-.*/i, "")
    Projectdependency.where(
      :group_id => product.group_id,
      :artifact_id => product.artifact_id
      ).update_all(:version_current => newest_version)
  end

  def self.update_outdated_maven_pd product
    multi_log "update_outdated_maven for #{product.language}:#{product.prod_key}"
    dependencies = Projectdependency.where(
      :group_id => product.group_id,
      :artifact_id => product.artifact_id)
    dependencies.each do |dependency|
      ProjectdependencyService.update_outdated!( dependency )
      ProjectService.update_sums( dependency.project )
    end
  end

  def self.update_current_for_pd product
    newest_version = product.version.to_s.gsub(/-redhat-.*/i, "")
    Projectdependency.where(
      :language => product.language,
      :prod_key => product.prod_key
      ).update_all(:version_current => newest_version)
  end

  def self.update_outdated_pd product
    dependencies = Projectdependency.where(
      :language => product.language,
      :prod_key => product.prod_key)
    dependencies.each do |dependency|
      ProjectdependencyService.update_outdated!( dependency )
      ProjectService.update_sums( dependency.project )
    end
  end


  private


    def self.multi_log msg
      p msg
      log.info msg
    end


    def self.log_exception e, logger = nil
      if logger
        logger.error e.message
        logger.error e.backtrace.join("\n")
      else
        p e.message
        p e.backtrace.join("\n")
        log.error e.message
        log.error e.backtrace.join("\n")
      end
    end


end
