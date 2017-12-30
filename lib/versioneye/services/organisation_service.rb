class OrganisationService < Versioneye::Service


  def self.create_new user, name
    if !Organisation.where({:name => name}).empty?
      raise "Organisation with name '#{name}' exists already. Please choose another name."
    end
    if Settings.instance.orga_creation_admin_only == true && user.admin == false
      raise "Only admins can create new organisations."
    end
    orga = Organisation.new({:name => name})
    orga.plan = Plan.free_plan
    orga.save
    create_default_lwl orga
    owners_team = Team.new(:name => Team::A_OWNERS)
    owners_team.add_member user
    owners_team.organisation = orga
    owners_team.save
    orga.teams.push owners_team
    orga.save
    orga
  end


  def self.create_new_for user
    orga_name = "#{user.username}_orga".downcase
    orga_name = orga_name.gsub("@", "").gsub(" ", "_").gsub(".", "").gsub(",", "")
    if !Organisation.where(:name => orga_name).first.nil?
      random = create_random_value
      orga_name = "#{orga_name}_#{random}"
    end
    create_new user, orga_name
  rescue => e
    log.error "ERROR in create_new_for(user) - #{e.message}"
    log.error e.backtrace.join("\n")
    nil
  end


  def self.update_plan organisation, plan_name_id
    stripe_token  = organisation.stripe_token
    customer_id   = organisation.stripe_customer_id
    customer      = nil
    if customer_id && stripe_token
      customer = StripeService.fetch_customer customer_id
    end
    if customer
      p " - update_plan for #{organisation.name} - #{plan_name_id} - stripe customer exist already, just update plan."
      customer.update_subscription( :plan => plan_name_id )
      organisation.plan = Plan.by_name_id plan_name_id
      saved = organisation.save
      p " - orga updated with new plan: #{saved}"
    else 
      p " - customer for #{organisation.name} does not exist"
    end
  rescue => e
    logger.error e.message
    logger.error e.backtrace.join("\n")
  end


  def self.inventory_diff_async orga_name, filter1, filter2
    orga = Organisation.where(:name => orga_name).first
    if orga.nil?
      log.error "ERROR in inventory_diff_async - no orga found for #{orga_name}"
      return nil
    end
    diff = InventoryDiff.new(:organisation_id => orga.ids)
    diff.save

    InventoryProducer.new({:type => "diff",
           :diff_id => diff.ids,
           :orga_name => orga_name,
           :filter1 => filter1,
           :filter2 => filter2}.to_json)

    diff.ids
  end


  def self.inventory_diff orga_name, filter1, filter2, diff_id = nil, use_cache = true
    orga = Organisation.where(:name => orga_name).first
    return nil if orga.nil?

    items_added = []
    items_removed = []

    inv1_obj = orga.component_list filter1[:team], filter1[:language], filter1[:version], filter1[:after_filter], use_cache, false
    inv2_obj = orga.component_list filter2[:team], filter2[:language], filter2[:version], filter2[:after_filter], use_cache, false

    inv1 = orga.component_list filter1[:team], filter1[:language], filter1[:version], filter1[:after_filter], true, true
    inv2 = orga.component_list filter2[:team], filter2[:language], filter2[:version], filter2[:after_filter], true, true

    inv1_set = []
    fill_inv_set inv1, inv1_set

    inv2_set = []
    fill_inv_set inv2, inv2_set

    items_removed = inv1_set - inv2_set
    items_added   = inv2_set - inv1_set

    idiff = if diff_id
              InventoryDiff.find diff_id
            else
              InventoryDiff.new
            end
    idiff.items_added = items_added
    idiff.items_removed = items_removed
    idiff.finished = true
    idiff.inventory1_id = inv1_obj.ids
    idiff.inventory2_id = inv2_obj.ids
    idiff.save
    idiff
  end


  def self.fill_inv_set col, set
    col.each do |element|
      current_prod = element.first
      language = current_prod.split(":").first
      deps = element.last
      deps.keys.each do |key|
        lang_prod_key = "#{language}::#{key}"
        set << lang_prod_key if !set.include?(lang_prod_key)
      end
    end
  end


  def self.delete orga
    return false if orga.nil?

    orga.projects.each do |project|
      ProjectService.destroy project
    end

    orga.teams.each do |team|
      TeamService.delete team
    end

    LicenseWhitelist.where(:organisation_id => orga.ids).each do |lwl|
      lwl.delete
    end

    orga.component_whitelists.each do |cwl|
      cwl.delete
    end

    if !orga.stripe_customer_id.to_s.empty?
      customer = StripeService.fetch_customer orga.stripe_customer_id
      if customer
        customer.update_subscription( :plan => Plan::A_PLAN_FREE )
        orga.plan = Plan.free_plan
        orga.save
      end
    end

    api = orga.api( false )
    api.delete
    api = orga.api( true )
    api.delete

    orga.delete
  end


  def self.owner? orga, user
    return false if orga.nil? || user.nil?

    team = Team.where(:organisation_id => orga.ids, :name => Team::A_OWNERS).first
    return false if team.nil?

    team.members.each do |member|
      next if member.nil? || member.user.nil?

      return true if member.user.ids.eql?(user.ids)
    end
    false
  end


  def self.member? orga, user
    return false if orga.nil? || user.nil?

    orga.teams.each do |team|
      team.members.each do |member|
        next if member.nil? || member.user.nil?

        return true if member.user.ids.eql?(user.ids)
      end
    end
    false
  end


  def self.allowed_to_transfer_projects? orga, user
    return false if orga.nil? || user.nil?
    return false if !member?( orga, user )
    return true  if owner?( orga, user )
    return true  if orga.mattp == true
    return false
  end

  def self.allowed_to_assign_teams? orga, user
    return false if orga.nil? || user.nil?
    return false if !member?( orga, user )
    return true  if owner?( orga, user )
    return true  if user.admin == true
    return true  if orga.matattp == true
    return false
  end


  # Attach a project to the organisation
  def self.transfer project, organisation
    return false if organisation.nil? || project.nil?

    project.organisation = organisation
    project.teams = [organisation.owner_team]
    project.license_whitelist_id = organisation.default_lwl_id
    project.component_whitelist_id = organisation.default_cwl_id
    result = project.save
    if result == true && ( !project.license_whitelist_id.nil? || !project.component_whitelist_id.nil? )
      ProjectUpdateService.update_async project
    end
    return result
  end


  def self.index user, only_owners = false
    return [] if user.nil?
    user.orgas only_owners
  end


  def self.orgas_allowed_to_transfer user
    organisations = index( user, false )
    orgas = []
    organisations.each do |orga|
      orgas.push(orga) if OrganisationService.allowed_to_transfer_projects?( orga, user )
    end
    orgas
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    []
  end


  def self.create_default_lwl orga
    list_name = 'default_lwl'
    lwl = LicenseWhitelistService.create orga, list_name
    return nil if lwl.nil?

    LicenseWhitelistService.default orga, list_name
    orga.reload
    lwl.add_license_element 'MIT'
    lwl.add_license_element 'BSD'
    lwl.add_license_element 'BSD-2-Clause'
    lwl.add_license_element 'BSD-3-Clause'
    lwl.add_license_element 'BSD-4-Clause'
    lwl.add_license_element 'BSD-4-Clause-UC'
    lwl.add_license_element 'Apache-1.0'
    lwl.add_license_element 'Apache-1.1'
    lwl.add_license_element 'Apache-2.0'
    lwl.add_license_element 'WTFPL'
    lwl.add_license_element 'Public Domain'
    lwl.add_license_element 'Unlicense'
    lwl.add_license_element 'CC0'
    lwl.add_license_element 'CC0-1.0'
    lwl.add_license_element 'ISC'
  end


  private


    def self.create_random_value
      chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
      value = ""
      5.times { value << chars[rand(chars.size)] }
      value
    end


end
