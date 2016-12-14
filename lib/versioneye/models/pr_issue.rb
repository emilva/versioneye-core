class PrIssue < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  A_SCM_GITHUB     = 'github'

  A_ISSUE_SECURITY        = 'SECURITY'
  A_ISSUE_LICENSE_UNKNOWN = 'LICENSE_UNKNOWN'

  field :file             , type: String
  field :language         , type: String
  field :prod_key         , type: String
  field :name             , type: String
  field :version_label    , type: String # pull request number
  field :version_requested, type: String
  field :version_current  , type: String
  field :license          , type: String
  field :issue_type       , type: String

  field :security_count   , type: Integer, :default => 0
  field :unknown_license  , type: Boolean, :default => false
  field :lwl_violation    , type: Boolean, :default => false
  field :license_violation, type: Boolean, :default => false

  belongs_to :pullrequest

  index({ pullrequest_id: 1, file: 1 }, { name: "prid_file_index",  background: true, unique: false })

end
