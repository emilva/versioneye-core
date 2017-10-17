class UserService < Versioneye::Service


  def self.search(term)
    User.where(:fullname.ne => 'Deleted', :include_in_autocomplete => true)
        .any_of({:username => /#{term}/i}, {:email => /#{term}/i})
  rescue => e
    log.error "ERROR in UserService.search - #{e.message}"
    log.error e.backtrace.join("\n")
    return []
  end


  def self.valid_user?(user, flash)
    unless User.email_valid?(user.email)
      flash[:error] = 'page_signup_error_email'
      return false
    end
    if user.fullname.nil? || user.fullname.empty?
      flash[:error] = 'page_signup_error_fullname'
      return false
    elsif user.password.nil? || user.password.empty? || user.password.size < 5
      flash[:error] = 'page_signup_error_password'
      return false
    elsif !user.terms
      flash[:error] = 'page_signup_error_terms'
      return false
    end
    true
  end


  def self.reset_password user
    random_value = create_random_value
    user.password = random_value # prevents using old password
    user.verification = create_random_token
    user.encrypt_password
    user.save
    UserMailer.reset_password( user ).deliver_now
  end


  def self.delete user, why = nil
    NotificationService.remove_notifications user

    orgas = OrganisationService.index user
    orgas.each do |orga|
      orga.teams.each do |team|
        team.remove_member user
      end
    end

    emails = user.emails
    if emails && !emails.empty?
      emails.each do |email|
        email.delete
      end
    end

    random              = create_random_value
    user.deleted_user   = true
    user.email          = "#{random}_#{user.email}"
    user.prev_fullname  = user.fullname
    user.fullname       = 'Deleted'
    user.username       = "#{random}_#{user.username}"

    user.github_id      = nil
    user.github_login   = nil
    user.github_token   = nil
    user.github_scope   = nil

    user.bitbucket_id     = nil
    user.bitbucket_token  = nil
    user.bitbucket_secret = nil

    api = user.api
    api.delete

    user.products.clear
    if user.save
      notify_rob( user, why )
      return true
    end

    BitbucketRepo.by_user( user ).delete_all
    GithubRepo.by_user( user ).delete_all

    false
  end


  def self.active_users
    User.all.select do |user|
      ( (!user['product_ids'].nil? && user['product_ids'].count > 0) or
       Versioncomment.where(user_id: user.id).exists? or
       Project.where(user_id: user.id).exists?
      )
    end
  end


  def self.update_languages
    User.all.each do |user|
      products = user.products
      if products.nil? || products.empty?
        user.languages = nil
      else
        user.languages = user.products.distinct(:language)
      end
      user.orgas.each do |orga|
        langs = orga.projects.distinct(:language)
        user.languages << langs if !langs.empty?
      end
      user.save
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end


  def self.all_users_paged
    count = User.count()
    page = 100
    iterations = count / page
    iterations += 1
    (0..iterations).each do |i|
      skip = i * page
      users = User.all().skip(skip).limit(page)

      yield users

      # co = i * page
      # log_msg = "all_users_paged iteration: #{i} - users processed: #{co}"
      # p log_msg
      # log.info log_msg
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  private

    def self.notify_rob user, why
      UserMailer.deleted( user, why ).deliver_now
    rescue => e
      log.error e.message
      log.error e.backtrace.join("\n")
    end


    def self.create_random_token(length = 25)
      SecureRandom.urlsafe_base64(length)
    end


    def self.create_random_value
      chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
      value = ''
      10.times { value << chars[rand(chars.size)] }
      value
    end


end
