class TeamNotificationService  < Versioneye::Service


  def self.start serial = true
    Plan.all.desc(:prio).each do |plan|
      process_orgas plan.organisations, serial
    end
    orgas = Organisation.where(:plan_id => nil)
    process_orgas orgas, serial
  end


  def self.process_orgas organisations, serial
    organisations.each do |orga|
      if serial
        process_orga( orga )
      else
        TeamNotificationProducer.new(orga.ids)
      end
    end
  end


  def self.process_orga orga
    update_projects orga
    env = Settings.instance.environment
    if env.to_s.eql?("enterprise")
      process_teams orga
    end
  end


  def self.process_teams orga
    orga.teams.each do |team|
      process_team orga, team
    end
  end


  def self.process_team orga, team
    log.info " - Process orga #{orga.name} and team #{team.name}"
    return nil if team.notifications_all_disabled?
    return nil if team.notify_today? == false
    return nil if team.emails.empty?
    return nil if MailTrack.send_team_email_already?(MailTrack::A_TEMPLATE_TEAM_NOTIFICATION, orga.ids, team.ids)

    projects = orga.team_projects team.ids
    return nil if projects.nil? || projects.empty?

    affected_projects = filter_affected projects, team
    if affected_projects.nil? || affected_projects.empty?
      log.info "  - No affected projects for orga #{orga.name} / team #{team.name}"
      return nil
    end

    TeamMailer.team_notification( orga, team, affected_projects ).deliver_now
    MailTrack.add_team MailTrack::A_TEMPLATE_TEAM_NOTIFICATION, orga.ids, team.ids, projects.map(&:ids)
  end


  def self.update_projects orga
    return nil if orga.nil?
    return nil if orga.projects.nil?
    return nil if orga.projects.empty?

    orga.projects.each do |project|
      next if project_processed?( orga, project )

      p " -- Update project #{project.language}/#{project.name}"
      ProjectUpdateService.update project
    end
    p " -- All projects updated for orga #{orga.name}"
  end


  def self.filter_affected projects, team
    affected_projects = []
    projects.each do |project|
      if team.version_notifications == true && project.out_number_sum.to_i > 0
        affected_projects << project
        next
      end

      if team.license_notifications == true && (project.licenses_red_sum.to_i > 0 || project.licenses_unknown_sum.to_i > 0)
        affected_projects << project
        next
      end

      if team.security_notifications == true && project.sv_count_sum.to_i > 0
        affected_projects << project
        next
      end
    end
    affected_projects
  end


  private


    def self.project_processed?( orga, project )
      project.teams.each do |team|
        return true if MailTrack.send_team_email_already?(MailTrack::A_TEMPLATE_TEAM_NOTIFICATION, orga.ids, team.ids)
      end
      false
    end


end
