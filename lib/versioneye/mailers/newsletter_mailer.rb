class NewsletterMailer < ActionMailer::Base

  layout 'email_html_layout'
  default from: "\"VersionEye\" <notify@versioneye.com>"

  def newsletter_new_features_email(user)
    @user = user
    mail(:to => @user.email, :subject => 'The Heartbleed Bug') do |format|
      format.html{ render layout: 'email_html_layout' }
    end
  end

end
