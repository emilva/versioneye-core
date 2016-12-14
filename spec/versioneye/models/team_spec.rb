require 'spec_helper'

describe Team do

  before(:each) do
    Plan.create_defaults
    @user = User.new({:fullname => 'Hans Tanz', :username => 'hanstanz',
      :email => 'hans@tanz.de', :password => 'password', :salt => 'salt',
      :terms => true, :datenerhebung => true})
    @user.save
    @orga = OrganisationService.create_new_for @user
    expect( @orga.save ).to be_truthy
  end

  describe "to_s" do
    it "returns the name" do
      team = Team.new({:name => 'owner' })
      expect(team.to_s).to eq('owner')
    end
  end

  describe "to_param" do
    it "returns the name" do
      team = Team.new({:name => 'owner' })
      expect(team.to_param).to eq('owner')
    end
  end

  describe "notifications_all_disabled?" do
    it "returns false by default" do
      team = Team.new({:name => 'owner' })
      expect(team.notifications_all_disabled?).to be_falsey
    end
    it "returns true" do
      team = Team.new({:name => 'owner' })
      team.version_notifications  = false
      team.license_notifications  = false
      team.security_notifications = false
      expect(team.notifications_all_disabled?).to be_truthy
    end
  end

  describe "notify_today?" do
    it "returns false" do
      team = Team.new({:name => 'owner' })
      wday = DateTime.now.strftime('%A')
      if wday.eql?('Sunday')
        team.sunday = false
      elsif wday.eql?('Monday')
        team.monday = false
      elsif wday.eql?('Tuesday')
        team.tuesday = false
      elsif wday.eql?('Wednesday')
        team.wednesday = false
      elsif wday.eql?('Thursday')
        team.thursday = false
      elsif wday.eql?('Friday')
        team.friday = false
      elsif wday.eql?('Saturday')
        team.saturday = false
      end
      expect(team.notify_today?).to be_falsey
    end
    it "returns true" do
      team = Team.new({:name => 'owner' })
      wday = DateTime.now.strftime('%A')
      if wday.eql?('Sunday')
        team.sunday = true
      elsif wday.eql?('Monday')
        team.monday = true
      elsif wday.eql?('Tuesday')
        team.tuesday = true
      elsif wday.eql?('Wednesday')
        team.wednesday = true
      elsif wday.eql?('Thursday')
        team.thursday = true
      elsif wday.eql?('Friday')
        team.friday = true
      elsif wday.eql?('Saturday')
        team.saturday = true
      end
      expect(team.notify_today?).to be_truthy
    end
  end

  describe "add_member" do
    it "adds an member" do
      # false because already member
      expect(@orga.teams.first.add_member(@user)).to be_falsey
      expect(Team.first.members.count).to eq(1)

      # true because new member
      user2 = UserFactory.create_new 2
      expect(Team.first.add_member(user2)).to be_truthy
      expect(Team.first.members.count).to eq(2)
    end
  end

  describe "remove_member" do
    it "remove an member" do
      # Remove member
      team = @orga.teams.first
      expect(team.remove_member(@user)).to be_truthy
      expect(Team.first.members.count).to eq(0)
      team.reload

      # returns false because member was already removed
      expect(team.remove_member(@user)).to be_falsey
      expect(Team.first.members.count).to eq(0)
    end
  end

  describe "is_member?" do
    it "is_member" do
      expect(@orga.teams.first.members.count).to eq(1)
      expect(@orga.teams.first.is_member?(@user)).to be_truthy
    end
    it "is not a member" do
      expect(@orga.teams.first.is_member?(nil)).to be_falsey
    end
    it "is not a member" do
      expect(@orga.teams.first.is_member?( UserFactory.create_new )).to be_falsey
    end
  end

end
