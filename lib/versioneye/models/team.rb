class Team < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  A_OWNERS = 'Owners'

  field :name, type: String

  field :version_notifications,  type: Boolean, default: true
  field :license_notifications,  type: Boolean, default: true
  field :security_notifications, type: Boolean, default: true

  field :monday,    type: Boolean, default: true
  field :tuesday,   type: Boolean, default: true
  field :wednesday, type: Boolean, default: true
  field :thursday,  type: Boolean, default: true
  field :friday,    type: Boolean, default: true
  field :saturday,  type: Boolean, default: false
  field :sunday,    type: Boolean, default: false

  has_many :members, class_name: 'TeamMember'

  belongs_to :organisation

  validates_presence_of   :name, :message => 'is mandatory!'
  validates_presence_of   :organisation, :message => 'is mandatory!'

  scope :by_organisation, ->(organisation) { where(organisation_id: organisation.ids).asc(:name) }

  def to_s
    name
  end

  def to_param
    name
  end

  def notifications_all_disabled?
    self.version_notifications  == false &&
    self.license_notifications  == false &&
    self.security_notifications == false
  end

  def notify_today?
    wday = DateTime.now.strftime('%A')
    return true if wday.eql?('Monday')    && self.monday
    return true if wday.eql?('Tuesday')   && self.tuesday
    return true if wday.eql?('Wednesday') && self.wednesday
    return true if wday.eql?('Thursday')  && self.thursday
    return true if wday.eql?('Friday')    && self.friday
    return true if wday.eql?('Saturday')  && self.saturday
    return true if wday.eql?('Sunday')    && self.sunday
    return false
  end

  def emails
    ems = []
    members.each do |member|
      next if member.user.nil?
      next if member.user.deleted_user

      email = member.user.email
      ems << email if !ems.include?( email )
    end
    ems.join(',')
  end

  def add_member user
    return false if user.nil?
    self.members.each do |member|
      return false if member.user.ids.eql?(user.ids)
    end
    tm = TeamMember.new({:user => user, :team => self})
    tm.save
  end

  def remove_member user
    return false if user.nil?
    self.members.each do |member|
      if member.user.ids.eql?(user.ids)
        member.delete
        return true
      end
    end
    false
  end

  def is_member? user
    return false if user.nil?
    self.members.each do |member|
      return true if member.user.ids.eql?(user.ids)
    end
    false
  end

end
