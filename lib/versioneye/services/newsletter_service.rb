class NewsletterService < Versioneye::Service


  def self.send_newsletter_features
    count = 0
    UserService.all_users_paged do |users|
      count = broadcast_to users, count
    end
    count
  end


  def self.broadcast_to users, count
    users.each do |user|
      next if user.deleted_user || user.email_inactive

      uns = UserNotificationSetting.fetch_or_create_notification_setting( user )
      next if uns.newsletter_features.nil?
      next if uns.newsletter_features == false

      count += self.send_email( user )
    end
    count
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    p e.message
    p e.backtrace.join("\n")
    count
  end


  def self.send_email( user )
    NewsletterMailer.newsletter_new_features_email( user ).deliver_now
    MailTrack.add user.ids, MailTrack::A_TEMPLATE_NEWSLETTER, nil
    log.info "Sent new feature newsletter to #{user.fullname}"
    p "Sent new feature newsletter to #{user.fullname}"
    1
  rescue => e
    user.email_send_error = e.message
    user.save
    log.error e.message
    log.error e.backtrace.join("\n")
    p e.message
    p e.backtrace.join("\n")
    0
  end


end
