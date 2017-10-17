class User < Versioneye::Model

  A_EMAIL_REGEX = /[\S]+\@[\S]+\.[\S]+\z/i

  include Mongoid::Document
  include Mongoid::Timestamps

  field :username          , type: String
  field :fullname          , type: String
  field :prev_fullname     , type: String
  field :email             , type: String
  field :email_inactive    , type: Boolean, default: false # Inactive recipients are ones that have generated a hard bounce or a spam complaint
  field :encrypted_password, type: String
  field :salt              , type: String
  field :admin             , type: Boolean, default: false
  field :deleted_user      , type: Boolean, default: false
  field :verification      , type: String
  field :terms             , type: Boolean
  field :datenerhebung     , type: Boolean
  field :privacy_products  , type: String, default: 'everybody'
  field :privacy_comments  , type: String, default: 'everybody'
  field :include_in_autocomplete, type: Boolean, default: true

  field :description, type: String
  field :location   , type: String
  field :time_zone  , type: String
  field :blog       , type: String

  field :promo_code, type: String
  field :refer_name, type: String

  field :github_id   , type: String
  field :github_login, type: String # Username on github
  field :github_token, type: String
  field :github_scope, type: String

  field :bitbucket_id,     type: String
  field :bitbucket_login,  type: String # Username on bitbucket
  field :bitbucket_token,  type: String
  field :bitbucket_secret, type: String
  field :bitbucket_scope,  type: String

  field :stash_slug,   type: String # Username on stash
  field :stash_token,  type: String
  field :stash_secret, type: String

  field :languages, type: String
  field :uniq_langs, type: Array

  # Contains the <language::prod_key> downcased pairs for the packages which user is maintainer for.
  field :maintainer, type: Array

  field :email_send_error, type: String

  # *** RELATIONS START ***
  has_one    :user_permission
  has_one    :user_notification_setting
  has_many   :projects
  has_many   :github_repos
  has_many   :bitbucket_repos
  has_many   :stash_repos

  has_and_belongs_to_many :products
  # *** RELATIONS END ***

  index({ username: 1 },     { name: "username_index",     background: true, unique: true })
  index({ email: 1 },        { name: "email_index",        background: true, unique: true })
  index({ github_id: 1 },    { name: "github_id_index",    background: true })
  index({ bitbucket_id: 1 }, { name: "bitbucket_id_index", background: true })
  index({ verification: 1 }, { name: "verification_index", background: true })
  # index({ username: "text", email: "text"}, {weights: {username: 10, email: 5}, name: "TextIndex"})

  validates_presence_of :username          , :message => 'is mandatory!'
  validates_presence_of :fullname          , :message => 'is mandatory!'
  validates_presence_of :email             , :message => 'is mandatory!'
  validates_presence_of :encrypted_password, :message => 'is mandatory!'
  validates_presence_of :salt              , :message => 'is mandatory!'
  validates_presence_of :terms             , :message => 'is mandatory!'
  validates_presence_of :datenerhebung     , :message => 'is mandatory!'

  validates_uniqueness_of :username          , :message => 'exist already.'
  validates_uniqueness_of :email             , :message => 'exist already.'

  validates_length_of :username, minimum: 2, maximum: 50, :message => 'length is not ok'
  validates_length_of :fullname, minimum: 2, maximum: 50, :message => 'length is not ok'

  validates_format_of :username, with: /\A[a-zA-Z0-9_-]+\z/
  validates_format_of :email   , :with => A_EMAIL_REGEX, :message => 'is not valid.'

  before_validation :downcase_email, :check_password

  scope :by_verification, ->(code){where(verification: code)}
  # scope :live_users     , where(verification: nil, deleted_user: false)
  scope :follows_equal  , ->(n){where(:product_ids.count.eq(n))}
  scope :follows_least  , ->(n){where(:product_ids.count >= n)}
  scope :follows_max    , ->(n){where(:product_ids.count <= n)}

  attr_accessor :password, :new_username

  before_save :check_terms

  def to_param
    username
  end

  def to_s
    result = "#{username} / #{fullname} / #{email}"
    result += " - verification: #{verification}" if verification
    result += " - verified account " if verification.nil?
    result += " - deleted " if deleted_user
    result
  end

  def create_verification
    random = create_random_value
    self.verification = secure_hash("#{random}--#{username}")
  end

  def send_verification_email
    UserMailer.verification_email(self, self.verification, self.email).deliver_now
  rescue => e
    User.log.error e.message
    User.log.error e.backtrace.join("\n")
  end

  def create_username
    name = fullname.strip
    if name.include?(" ")
      name = name.gsub!(" ", "")
    end
    if name.include?("-")
      name = name.gsub!("-", "")
    end
    if name.include?("@")
      name = name.gsub!("@", "")
    end
    if name.include?(".")
      name = name.gsub!(".", "")
    end
    user = User.find_by_username(name)
    if user
      name = name + create_random_value
    end
    self.username = name
  end


  def self.activate!(verification)
    return false if verification.to_s.strip.empty?

    user = User.where(verification: verification).shift
    return false if user.nil?

    user.verification = nil
    user.save
    return true
  end


  def activated?
    verification.nil?
  end

  def self.find_by_username( username )
    return nil if username.nil? || username.strip.empty?
    user = User.where( username: username ).shift
    user = User.where( username: /\A#{username}\z/i ).shift if user.nil?
    user
  end

  def self.find_by_email(email)
    return nil if email.to_s.strip.empty?
    user = User.where(email: email.downcase).shift  if user.nil?
    user = User.where(email: /\A#{email}\z/i).shift if user.nil?
    user
  end

  def self.find_by_id( id )
    return nil if id.to_s.empty?
    return User.find(id.to_s)
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

  def self.find_all( page_count )
    User.all().desc(:created_at).paginate(page: page_count, per_page: 30)
  end

  def emails
    UserEmail.where(user_id: self._id.to_s)
  end

  def emails_verified
    UserEmail.where(user_id: self._id.to_s, verification: nil)
  end

  def get_email email
    UserEmail.where( user_id: self._id.to_s, email: email ).shift
  end

  def has_password? submitted_password
    self.encrypted_password == encrypt(submitted_password)
  end

  def self.find_by_github_id github_id
    return nil if github_id.nil? || github_id.strip.empty?
    User.where(github_id: github_id).shift
  end

  def self.find_by_bitbucket_id(bitbucket_id)
    return nil if bitbucket_id.to_s.strip.empty?
    User.where(bitbucket_id: bitbucket_id).shift
  end

  def self.find_by_stash_slug( slug )
    return nil if slug.to_s.strip.empty?
    User.where( stash_slug: slug ).shift
  end

  def github_account_connected?
    !self.github_id.to_s.empty? && !self.github_token.to_s.empty?
  end

  def bitbucket_account_connected?
    !self.bitbucket_id.to_s.empty? && !self.bitbucket_token.to_s.empty?
  end

  def stash_account_connected?
    !self.stash_slug.to_s.empty? && !self.stash_token.to_s.empty?
  end


  def self.follows_max(n)
    User.all.select {|user| user['product_ids'].nil? or user['product_ids'].count < n}
  end

  def self.follows_least(n)
    User.all.select {|user| !user['product_ids'].nil? and user['product_ids'].count >= n}
  end

  def self.non_followers
    User.collection.find({'product_ids.0' => {'$exists' => false}})
  end

  def self.authenticate(email, submitted_password)
    user = User.find_by_email( email )
    user = User.find_by_username( email ) if user.nil?
    return nil  if user.nil? || user.deleted_user
    return user if user.has_password?(submitted_password)
    return nil
  end

  def self.authenticate_with_salt(id, coockie_salt)
    return nil if !id || !coockie_salt
    user = User.find( id )
    ( user && user.salt == coockie_salt ) ? user : nil
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

  def self.authenticate_with_apikey(token)
    api = Api.where(api_key: token).shift
    return nil if api.nil?
    return nil if api.user_id.nil?

    user = User.find_by_id( api.user_id )
    return nil if user.nil?

    user
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

  def api
    api = Api.where( user_id: self.ids ).first
    api = Api.create_new( self ) if api.nil?
    api
  end

  def api_key
    self.api.api_key
  end

  def self.username_valid?(username)
    user = User.find_by_username(username)
    return user.nil?
  end

  def self.email_valid?(email)
    return false if email.to_s.empty?

    user = find_by_email(email)
    user_email = UserEmail.find_by_email(email)
    return user.nil? && user_email.nil?
  end

  def password_valid?(password)
    enc_password = encrypt(password)
    enc_password.eql?(encrypted_password)
  end

  def update_password( password )
    self.password = password
    encrypt_password
    save
  end

  def update_from_github_json(json_user, token)
    json_user.deep_symbolize_keys!
    self.username = json_user[:login]
    if self.username.to_s.empty?
      self.username = create_random_value
    end
    self.cleanup_username
    self.ensure_unique_username

    self.fullname = json_user[:name]
    if self.fullname.to_s.empty?
      self.fullname = self.username
    end

    self.github_id    = json_user[:id]
    self.github_login = json_user[:login]
    self.github_token = token
    self.password     = create_random_value
  end

  def update_from_bitbucket_json(user_info, token, secret, scopes = "read_write")
    self[:username] = user_info[:username]
    if self.username.to_s.empty?
      self.username = create_random_value
    end
    self.cleanup_username
    self.ensure_unique_username

    self[:fullname] = user_info[:display_name]
    if self.fullname.to_s.empty?
      self.fullname = self.username
    end

    self.bitbucket_id     = user_info[:username]
    self.bitbucket_login  = user_info[:username]
    self.bitbucket_token  = token
    self.bitbucket_secret = secret
    self.bitbucket_scope  = scopes
  end

  def update_from_stash_json( user_info, token, secret )
    self.username = user_info[:slug]
    if self.username.to_s.empty?
      self.username = create_random_value
    end
    self.cleanup_username
    self.ensure_unique_username

    self.fullname = user_info[:name]
    if self.fullname.to_s.empty?
      self.fullname = self.username
    end

    self.stash_slug = user_info[:slug]
    self.email = user_info[:emailAddress]
    self.stash_token = token
    self.stash_secret = secret
    self.terms = true
    self.datenerhebung = true
  end

  def ensure_unique_username
    user_db = User.find_by_username( self.username )
    unless user_db.nil?
      random_value = create_random_value
      self.username = "#{self.username}_#{random_value}"
    end
  end

  def cleanup_username
    self.username = self.username.gsub(" ", "")
    self.username = self.username.gsub(".", "")
    self.username = self.username.gsub("-", "")
    self.username = self.username.gsub("@", "")
    self.username
  end

  def fetch_or_create_permissions
    if self.user_permission.nil?
      self.user_permission = UserPermission.new
      self.user_permission.save
    end
    self.user_permission
  end

  #-- ElasticSearch mapping ------------------
  def to_indexed_json
    {
      :_id => self.id.to_s,
      :_type => "user",
      :fullname => self[:fullname],
      :username => self[:username],
      :email => self[:email]
    }
  end

  def encrypt_password
    self.salt = make_salt if new_record?
    self.encrypted_password = encrypt(password)
  end

  def add_maintainer key
    self.maintainer = [] if self.maintainer.nil?
    if !self.maintainer.include?(key)
      self.maintainer.push( key )
      return true
    end
    false
  end


  # Returns all organisations there the given user
  # is member in. If `only_owners` is true, only the
  # organisations are returned there the given user
  # is in the owner team.
  def orgas only_owners = false
    return Organisation.all if self.admin == true

    tms = TeamMember.where(:user_id => self.ids)
    return [] if tms.empty?

    organisations = []
    orga_ids = []
    tms.each do |tm|
      if tm.team.nil?
        tm.delete
        next
      end
      next if only_owners == true && !tm.team.name.eql?(Team::A_OWNERS)

      orga = tm.team.organisation
      next if orga.nil?
      next if orga_ids.include?(orga.ids)

      orga_ids.push(orga.ids)
      organisations.push(orga)
    end
    organisations
  end


  private

    def check_terms
      if self.terms == false || self.terms == nil
        self.errors.messages[:terms] = ["must be accepted"]
        throw(:abort)
      end

      if self.datenerhebung == false || self.datenerhebung == nil
        self.errors.messages[:datenerhebung] = ["must be accepted"]
        throw(:abort)
      end

      return true
    end

    def check_password
      return nil if new_record? == false
      encrypt_password
    end

    def downcase_email
      self.email = self.email.downcase if self.email.present?
    end

    def create_random_value
      chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
      value = ""
      10.times { value << chars[rand(chars.size)] }
      value
    end

    def make_salt
      secure_hash("#{Time.now.utc}--#{password}")
    end

    def encrypt(string)
      secure_hash("#{salt}--#{string}")
    end

    def secure_hash(string)
      Digest::SHA2.hexdigest(string)
    end

end
