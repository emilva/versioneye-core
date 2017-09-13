class Organisation < Versioneye::Model

  require 'benchmark'

  include Mongoid::Document
  include Mongoid::Timestamps

  field :name,     type: String
  field :company,  type: String
  field :location, type: String
  field :email,    type: String
  field :website,  type: String

  field :mattp,    type: Boolean, default: false # mattp    = member allowed to transfer projects to this organisation
  field :matattp,  type: Boolean, default: false # matattp  = member allowed to assign teams to projects

  # Team members are allowed to add new team members to their own team
  field :matanmtt, type: Boolean, default: false # matanmtt = member allowed to add new members to team

  field :stripe_token      , type: String
  field :stripe_customer_id, type: String

  field :max_private_projects, type: Integer, default: 0  # max closed source projects allowed
  field :max_os_projects     , type: Integer, default: 0  # max Open Source projects allowed
  field :pdf_exports         , type: Boolean, default: false
  field :change_visibility   , type: Boolean, default: false

  # Skip license check on pull requests
  field :skip_license_check_on_pr, type: Boolean, default: false

  # tracking plan period for organisations who don't pay with cc.
  field :plan_period_start, type: Time
  field :plan_period_end  , type: Time

  # Tracking Enterprise trial users
  field :trial_start, type: Time
  field :trial_end  , type: Time

  # Internal notes. Not visible on web page.
  field :notes, type: String

  belongs_to :plan
  has_one    :billing_address
  has_many   :projects
  has_many   :teams
  has_many   :license_whitelists
  has_many   :component_whitelists

  validates_presence_of   :name, :message => 'is mandatory!'
  validates_uniqueness_of :name, :message => 'exist already.'

  index({ name: 1 }, { name: "name_index", background: true, unique: true })


  def to_s
    name
  end


  def to_param
    name
  end


  def self.by_name name
    Organisation.where(:name => name).first
  end


  def receipts
    Receipt.where(:organisation_id => self.ids)
  end


  def api( read_only = false )
    api = Api.where( active: true, organisation_id: self.ids, read_only: read_only ).first
    api = Api.create_new_for_orga( self, read_only ) if api.nil?
    api
  end


  def api_key( read_only = false )
    self.api( read_only ).api_key
  end


  def fetch_or_create_billing_address
    if self.billing_address.nil?
      self.billing_address = BillingAddress.new
    end
    self.billing_address
  end


  def default_lwl_id
    return nil if license_whitelists.nil? || license_whitelists.empty?

    license_whitelists.each do |lwl|
      return lwl.ids if lwl.default == true
    end
    nil
  end


  def default_lwl
    lwl_id = default_lwl_id
    return nil if lwl_id.nil?

    LicenseWhitelist.find lwl_id
  end


  def default_cwl_id
    return nil if component_whitelists.nil? || component_whitelists.empty?

    component_whitelists.each do |cwl|
      return cwl.ids if cwl.default == true
    end
    nil
  end


  def team_projects team_id
    projects.parents.where(:team_ids => team_id, :temp => false)
  end


  def parent_projects
    projects.parents.where(:temp => false)
  end


  def owner_team
    teams.each do |team|
      return team if team.name.eql?(Team::A_OWNERS)
    end
    nil
  end


  def teams_by user
    return [] if user.nil?

    ts = []
    teams.each do |team|
      team.members.each do |member|
        next if member.user.nil?

        ts << team if member.user.ids.eql?(user.ids)
      end
    end
    ts
  end


  def team_by name
    return nil if name.to_s.empty?
    teams.where(:name => name).first
  end


  def unknown_license_deps
    deps = []
    projects.each do |project|
      pdeps = project.unknown_license_deps
      pdeps.each do |dep|
        prod_key = dep.prod_key
        prod_key = "#{dep.group_id}/#{dep.artifact_id}" if prod_key.to_s.empty?
        k = "#{dep.language}:#{prod_key}:#{dep.version_requested}"
        next if deps.include?( k )
        next if k.match(/com\.hybris/)

        deps.push k
        p "#{k} - #{dep.ids}"
      end
    end
    deps
  end


  def component_list_csv team = 'ALL', language = nil, version = nil, after_filter = 'ALL'
    comps = component_list team, language, version, after_filter
    csv_string = CSV.generate(:col_sep => ";") do |csv|
      csv << ['Language', 'Dependency', 'Newest Version', ' Used Version', 'License', 'Security Vulnerabilities', 'Project ID', 'Project Name', 'Project Version', 'Project GroupId', 'Project ArtifactId']
      comps.keys.each do |key|
        dep_lang = key.split(":")[0]
        newest_version = key.split(":")[2]
        dep = comps[key]
        dep.keys.each do |dep_version_key|
          sps = dep_version_key.split("::")
          prod_key = sps[0]
          dep_version = sps[1]
          dep_license = sps[2]
          dep_sv_count = sps[3]
          dep[dep_version_key].each do |pr|
            csv << [dep_lang, prod_key, newest_version, dep_version, dep_license, dep_sv_count, pr[:project_id], pr[:project_name], pr[:project_version], pr[:project_group_id], pr[:project_artifact_id]]
          end
        end
      end
    end
    csv_string
  end

  # https://github.com/versioneye/versioneye-api/blob/master/docs/api/v2/organisation.md
  def component_list team = 'ALL', language = nil, version = nil, after_filter = 'ALL', use_cache = true, return_hash = true
    return {} if projects.to_a.empty?

    inventory = Inventory.find_or_create_by( :orga_name => self.name,
                                             :team_name => team,
                                             :language => language,
                                             :project_version => version,
                                             :post_filter => after_filter )
    hour_ago = Time.now - 1.hour
    if use_cache && inventory.updated_at > hour_ago && !inventory.inventory_items.empty?
      return build_comps_hash_from( inventory ) if return_hash == true
      return inventory
    end

    inventory.inventory_items.delete_all
    inventory.updated_at = Time.now
    inventory.save

    comps = {}
    dep_projs = []
    projects.each do |project|
      if project.teams.nil? || project.teams.empty?
        project.teams = [self.owner_team]
        project.save
      end

      next if !language.to_s.empty? && !language.to_s.eql?('ALL') && !project.language.to_s.downcase.eql?( language.to_s.downcase )
      next if !version.to_s.empty?  && !version.to_s.eql?('ALL')  && !project.version.to_s.downcase.eql?(  version.to_s.downcase  )
      next if team_match?(team, project) == false

      time = Benchmark.measure { collect_components( inventory, project, project.dependencies, comps, dep_projs ) }
      p "#{time.real} for #{project.ids} - #{project.name}"
      next if project.children.count == 0

      project.children.each do |child|
        if child.teams.to_a.empty?
          child.teams = project.teams
          child.save
        end

        time = Benchmark.measure { collect_components( inventory, child, child.dependencies, comps, dep_projs ) }
        p " - #{time.real} for child #{project.ids} - #{project.name}"
      end
    end

    if after_filter.to_s.eql?('duplicates_only')
      return duplicates_only_filter( comps ) if return_hash == true
      return inventory
    elsif after_filter.to_s.eql?('show_duplicates')
      return show_duplicates_filter( inventory, comps ) if return_hash == true
      return inventory
    end

    return comps if return_hash == true
    return inventory
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    {}
  end


  def unique_languages
    return [] if projects.nil? || projects.empty?

    languages = []
    projects.parents.each do |project|
      languages << project.language if !languages.include?( project.language )
    end

    languages
  end


  def unique_versions
    return [] if projects.nil? || projects.empty?

    versions = []
    projects.parents.each do |project|
      next if project.version.to_s.empty?
      versions << project.version if !versions.include?( project.version )
    end

    versions
  end

  def comp_bucket_count
    ApiCmp.where( :api_key => self.api_key ).count
  end

  def os_project_count
    Project.where( organisation_id: self.ids, private_project: false, :parent_id => nil ).count
  end

  def private_project_count
    Project.where( organisation_id: self.ids, private_project: true, :parent_id => nil ).count
  end

  def max_private_projects_count
    return self.max_private_projects  if self.max_private_projects > 0
    return self.plan.private_projects if !self.plan.nil?
    1
  end

  def max_os_projects_count
    return self.max_os_projects  if self.max_os_projects > 0
    return self.plan.os_projects if !self.plan.nil?
    1
  end

  def pdf_exports_allowed?
    return true if self.pdf_exports == true
    return true if self.plan.price.to_i > 20
    return false
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end

  def change_visibility_allowed?
    return true if Settings.instance.environment.eql?("enterprise")
    return true if self.change_visibility == true
    return true if self.plan.price.to_i > 0
    return false
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end


  private


    def team_match?(team, project)
      team_match = false
      project.teams.each do |team_object|
        if team.to_s.eql?('ALL') || team_object.ids.eql?(team.to_s) || team_object.name.eql?(team.to_s)
          return true
        end
      end
      false
    end


    def show_duplicates_filter( inventory, comps )
      inventory.inventory_items.delete_all
      inventory.updated_at = Time.now
      inventory.save

      response = {}
      project_ids = Project.where(:organisation_id => self.ids).distinct(:id)
      comps.keys.each do |key|
        sps = key.split(":")
        language = sps[0]
        prod_key = sps[1]
        pdeps = Projectdependency.where(:language => language, :prod_key => prod_key, :project_id.in => project_ids)
        next if pdeps.count < 2

        team_names = uniq_teams( pdeps )
        next if team_names.count < 2

        collect_components inventory, nil, pdeps, response
      end
      response
    end

    def uniq_teams project_dependencies
      team_names = []
      project_dependencies.each do |pdep|
        project = pdep.project
        project.teams.each do |team|
          team_names << team.name if !team_names.include?( team.name )
        end
      end
      team_names
    end


    def duplicates_only_filter( comps )
      response = {}
      comps.keys.each do |key|
        if comps[key].keys.count > 1
          response[key] = comps[key]
        end
      end
      response
    end


    def collect_components inventory, project, project_dependencies, comps, dep_projs = []
      project_dependencies.each do |dep|
        component_key = "#{dep.language}:#{dep.possible_prod_key}:#{dep.version_current}"
        comps[component_key] = {} if (!comps.keys.include?( component_key ))

        version_key = "#{dep.possible_prod_key}::#{dep.version_requested}::#{dep.licenses_string}::#{dep.sv_ids.count}"
        comps[component_key][version_key] = [] if comps[component_key][version_key].nil?

        project = dep.project if project.nil?
        if project && dep.project && !dep.project.ids.eql?( project.ids )
          project = dep.project
        end
        dep_pro_key = "#{version_key}_#{project.ids}"
        next if dep_projs.include?( dep_pro_key )

        team_names = nil
        team_names = project.teams.map(&:name) if !project.teams.nil? && !project.teams.empty?
        values = {:project_language => project.language, :project_name => project.name,
               :project_id => project.ids, :project_version => project.version,
               :project_group_id => project.group_id, :project_artifact_id => project.artifact_id,
               :project_teams => team_names}
        comps[component_key][version_key] << values
        dep_projs.push dep_pro_key

        if inventory
          inventory.inventory_items.push InventoryItem.new( {:lpkv => component_key, :comp_key => version_key}.merge(values) )
        end
      end
      comps
    end


    def build_comps_hash_from inventory
      comps = {}
      inventory.inventory_items.desc(:lpkv, :comp_key).each do |item|
        comps[item.lpkv] = {} if (!comps.keys.include?( item.lpkv ) )
        comps[item.lpkv][item.comp_key] = [] if comps[item.lpkv][item.comp_key].nil?
        comps[item.lpkv][item.comp_key] << {:project_language => item.project_language, :project_name => item.project_name,
               :project_id => item.project_id, :project_version => item.project_version,
               :project_group_id => item.project_group_id, :project_artifact_id => item.project_artifact_id,
               :project_teams => item.project_teams}
      end
      comps
    end

end
