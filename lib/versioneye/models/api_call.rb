class ApiCall < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  A_OP_CREATE = 'CREATE'
  A_OP_UPDATE = 'UPDATE'
  A_OP_DELETE = 'DELETE'

  field :api_key    , type: String
  field :user_id    , type: String
  field :organisation_id, type: String
  field :project_id , type: String
  field :language   , type: String
  field :prod_key   , type: String
  field :operation  , type: String
  field :fullpath   , type: String
  field :http_method, type: String
  field :ip         , type: String

  # Expire after 60 days
  index({ created_at: 1 }, { name: "created_at_ttl", background: true, expire_after_seconds: 5184000 })
  index({ created_at: 1, ip: 1 }, { name: "created_at_id_key_index", background: true })
  index({ created_at: 1, api_key: 1 }, { name: "created_at_api_key_index", background: true })
  index({ api_key: 1 }, { name: "api_key_index", background: true })
  index({ user_id: 1 }, { name: "user_id_index", background: true })
  index({ ip: 1 }, { name: "ip_index", background: true })

  validates :fullpath, presence: true

  scope :by_user,    ->(user)   { where(user_id: user.id.to_s) }
  scope :by_api_key, ->(api_key){ where(api_key: api_key) }
  scope :today,      ->{ where(:created_at.gte => Date.today.midnight, :created_at.lt => Date.tomorrow.midnight) }

  def user
    User.find user_id
  end

  def project
    Project.find project_id
  end

  def organisation
    Organisation.find organisation_id
  end

end
