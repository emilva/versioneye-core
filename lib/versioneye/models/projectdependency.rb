class Projectdependency < Versioneye::Model

  require 'naturalsorter'

  # This Model describes the relationship between a project and a software component / dependency
  # This Model describes 1 dependency of a project

  include Mongoid::Document
  include Mongoid::Timestamps

  # This project dependency refers to the product with the given language and prod_key
  field :language   , type: String
  field :prod_key   , type: String
  field :ext_link   , type: String # Link to external package. For example zip file on GitHub / Google Code.

  field :name       , type: String
  field :group_id   , type: String # Maven specific
  field :artifact_id, type: String # Maven specific
  field :target,      type: String #Nuget specific to specify runtime

  field :version_current  , type: String  # the newest version from the database
  field :version_requested, type: String  # requested version from the project file -> locked version
  field :version_label    , type: String  # the version number from the projectfile (Gemfile, package.json)
  field :comperator       , type: String, :default => '='
  field :scope            , type: String, :default => Dependency::A_SCOPE_COMPILE
  field :release          , type: Boolean
  field :stability        , type: String, :default => VersionTagRecognizer::A_STABILITY_STABLE

  field :outdated           , type: Boolean
  field :outdated_updated_at, type: DateTime, :default => DateTime.now
  field :muted              , type: Boolean , :default => false
  field :mute_message       , type: String

  field :sv_ids           , type: Array, default: []  # Array of SecurityVulnerability IDs

  # This only shows if the license whitelist is violated, without taking the componente whitelist into account
  field :lwl_violation    , type: String # [nil, partial, yes]

  # This flag takes lwl and cwl into account and the optimistic/pesimistic mode from the lwl.
  field :license_violation, type: Boolean, :default => false

  belongs_to :project, optional: true

  embeds_many :license_caches, cascade_callbacks: true


  index({project_id: 1}, { name: "project_index", background: true})
  index({language: 1, prod_key: 1}, { name: "lang_prod_key_index", background: true})


  def to_s
    "<Projectdependency: #{project} depends on #{name} (#{version_label}/#{version_requested}) current: #{version_current} >"
  end


  def list_licenses
    p " - #{self.language}:#{self.prod_key}"
    license_caches.each do |lc|
      p " -- #{lc.to_s}"
    end
  end


  def licenses_string
    return 'UNKNOWN' if license_caches.nil? || license_caches.to_a.empty?

    license_caches.map { |lc| "#{lc.name}" }.join(", ")
  end


  def language_esc lang = nil
    lang = self.language if lang.nil?
    return nil if lang.to_s.empty?
    Product.encode_language lang
  end


  def self.find_by_id id
    Projectdependency.find id
  rescue => e
    nil
  end


  def version
    version_requested
  end


  def security_vulnerabilities
    return nil if sv_ids.to_a.empty?
    SecurityVulnerability.where(:_id.in => sv_ids)
  end


  def product
    if project && project.project_type.to_s.eql?( Project::A_TYPE_BOWER )
      product = Product.fetch_bower name
      return product if product
    end

    if !group_id.to_s.empty? && !artifact_id.to_s.empty?
      product = Product.find_by_group_and_artifact self.group_id, self.artifact_id
      return product if product
    end

    Product.fetch_product( self.language, self.prod_key.to_s )
  end


  def find_or_init_product
    if project && project.project_type.to_s.eql?( Project::A_TYPE_BOWER )
      product = Product.fetch_bower name
      return product if product
    end

    if !group_id.to_s.empty? && !artifact_id.to_s.empty?
      product = Product.find_by_group_and_artifact self.group_id, self.artifact_id
      return product if product
    end

    pk = prod_key
    pk = name.to_s.downcase if pk.to_s.empty?
    product = Product.fetch_product( language, pk )
    if product
      self.update_attribute(:prod_key, pk)
      return product
    end

    init_product
  end


  def possible_prod_key
    return self.prod_key if !self.prod_key.to_s.empty?

    possible_prod_key = self.name.to_s.downcase
    if self.group_id && self.artifact_id
      possible_prod_key = "#{self.group_id}/#{self.artifact_id}"
    end
    possible_prod_key
  end

  def cwl_key
    return "#{group_id}:#{artifact_id}:#{version_requested}"       if !group_id.to_s.empty? && !artifact_id.to_s.empty?
    return "#{language.downcase}:#{prod_key}:#{version_requested}" if !prod_key.to_s.empty?
    return "#{language.downcase}:#{name}:#{version_requested}"
  end


  def unknown?
    prod_key.nil? && ext_link.nil?
  end


  def known?
    !self.unknown?
  end


  def get_binding
    binding()
  end


  private


    def init_product
      product             = Product.new
      product.name        = self.name
      product.language    = self.language if self.language
      product.group_id    = self.group_id.to_s.downcase
      product.artifact_id = self.artifact_id.to_s.downcase
      product
    end

end
