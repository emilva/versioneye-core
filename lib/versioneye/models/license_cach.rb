class LicenseCach < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  field :name      , type: String # For example MIT
  field :url       , type: String # URL to the license text

  # true  = it's conform with the license whitelist of the project
  # false = it violates the license whitelist of the project
  # nil   = There is no license white list defined in the project
  field :on_whitelist, type: Boolean

  # cwl = component white list
  # true  = it's conform with the component whitelist of the project
  # false = it violates the component whitelist of the project
  # nil   = There is no component white list defined in the project
  field :on_cwl, type: Boolean

  field :license_id, type: String

  embedded_in :projectdependency

  def to_s
    "#{on_whitelist} - #{name} - #{url}"
  end

  def link
    url
  end

  def name_substitute
    name
  end

  def is_whitelisted?
    return nil if on_whitelist.nil? && on_cwl.nil?

    on_whitelist == true || on_cwl == true
  end

end
