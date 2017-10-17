class Webhook < Versioneye::Model
  include Mongoid::Document
  include Mongoid::Timestamps

  A_TYPE_GITHUB    = "github"
  A_TYPE_BITBUCKET = "bitbucket"
  A_TYPE_GITLAB    = "gitlab"


  field :scm, type: String  # a name of SCM, value: A_TYPE_XYZ
  field :fullname, type: String # the repo fullname, format: owner_name/repo_name ~> Repo mode

  # linked model ids
  field :project_id, type: String #to which project this hook belongs

  # foreign ids
  field :app_id,  type: String # app_id, required to Github authorization
  field :hook_id, type: String # id from SCM
  field :service_name, type: String, default: 'web' # the service name of the webhook, aka name on Github docs

  field :active, type: Boolean, default: true
  field :events, type: Array # array of string: ["push", "pull_request"]

  # URLs
  field :repo_url, type: String #optional url of REPO
  field :callback_url, type: String #our API url, which will be called by Github
  field :source_url, type: String #webhook's url on Github or other SCM
  field :test_url, type: String #url on which run test calls
  field :ping_url, type: String #url on which

  # configs table for saved webhook
  # fields from Github:
  #   {url: String, content_type: json|form, secret: String, insecure_ssl: "1|0"}
  #   source: https://developer.github.com/v3/repos/hooks/#create-a-hook
  field :config, type: Hash

  #-- VALIDATORS

  validates_presence_of :scm, :message => 'is mandatory'
  validates_presence_of :fullname, :message => 'is mandatory'

  #-- INDEXes

  index({scm: 1, fullname: 1}, {name: 'scm_fullname', background: true})

end
