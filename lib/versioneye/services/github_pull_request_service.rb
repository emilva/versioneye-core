class GithubPullRequestService < Versioneye::Service


  def self.process repo_name, branch, commits_url, pr_nr
    log.info "process #{repo_name}, #{branch}, #{commits_url}, #{pr_nr}"

    projects = Project.where(:scm_fullname => repo_name, :temp => false)
    pullrequest = create_pullrequest( repo_name, branch, pr_nr, projects, commits_url )
    if pullrequest.nil?
      log.error "ERROR in GithubPullRequestService. Could not create pullrequest! #{repo_name}:#{branch}:#{pr_nr}:#{commits_url}"
      return nil
    end

    set_status_pending pullrequest
    pullrequest.status = Pullrequest::A_STATUS_SUCCESS
    pullrequest.save
    filenames = []
    projects.each do |project|
      token = GithubUpdater.new.fetch_token_for project
      filename = project.s3_filename
      next if filenames.include?(filename)

      if project.organisation && !pullrequest.organisation_ids.include?( project.organisation.ids )
        pullrequest.organisation_ids << project.organisation.ids
        pullrequest.save
      end

      success = process_file( repo_name, project, branch, token, pullrequest )
      filenames << filename if success
    end
    finish_status pullrequest
    true
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end


  def self.set_status_pending pr
    status = {:state => pr.status, :description => "checking dependencies for security & licenses", :context => "VersionEye"}
    Github.update_status pr.scm_fullname, pr.commit_sha, pr.token, status
  end


  def self.finish_status pr
    target_url = "#{Settings.instance.server_url}/pullrequests/#{pr.ids}"
    status = {:state => pr.status, :description => pr.description, :context => "VersionEye", :target_url => target_url}
    Github.update_status pr.scm_fullname, pr.commit_sha, pr.token, status
  end


  def self.process_file repo_name, project, branch, token, pr
    filename = project.s3_filename
    tree_sha = pr.tree_sha
    project_file = Github.fetch_project_file_from_branch( repo_name, filename, branch, token, tree_sha )
    new_project  = ProjectImportService.create_project_from project_file, token
    new_project.name = filename
    new_project.temp = true
    new_project.temp_lock = true # prevent from deleting
    new_project.license_whitelist_id   = project.license_whitelist_id
    new_project.component_whitelist_id = project.component_whitelist_id
    new_project.save

    ProjectdependencyService.update_licenses_security new_project

    new_project.dependencies.each do |dep|
      if (!dep.sv_ids.empty? ||                # security vulnerability
           dep.license_caches.to_a.empty? ||   # unknown license
           dep.license_violation == true)      # violating lwl and/or cwl
        create_pr_issue filename, dep, pr
      end
    end

    new_project.temp_lock = false # allow to delete
    new_project.save
    true
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    false
  end


  def self.create_pr_issue filename, dep, pullrequest
    issue = PrIssue.new({
      :file => filename,
      :language => dep.language,
      :prod_key => dep.prod_key,
      :name => dep.name,
      :version_label => dep.version_label,
      :version_requested => dep.version_requested,
      :version_current => dep.version_current,
      :license => dep.licenses_string,
      :security_count =>  dep.sv_ids.count,
      :lwl_violation => dep.lwl_violation,
      :license_violation => dep.license_violation
      })
    issue.pullrequest = pullrequest
    if issue.save
      pullrequest.security_count        += 1 if issue.security_count > 0
      pullrequest.unknown_license_count += 1 if issue.license.eql?('UNKNOWN')
      pullrequest.lwl_violation_count   += 1 if issue.license_violation
      pullrequest.status = Pullrequest::A_STATUS_ERROR
      pullrequest.save
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.create_pullrequest repo_name, branch, pr_nr, projects, commits_url
    projects.each do |project|
      token       = GithubUpdater.new.fetch_token_for project
      last_commit = fetch_last_commit(commits_url, token)
      next if last_commit.nil?

      commit_sha  = last_commit[:sha]
      tree_sha    = last_commit[:commit][:tree][:sha]
      pullrequest = Pullrequest.new({
        :commits_url => commits_url,
        :scm_provider => Pullrequest::A_SCM_GITHUB,
        :scm_fullname => repo_name,
        :scm_branch => branch,
        :pr_number => pr_nr,
        :commit_sha => commit_sha,
        :tree_sha => tree_sha,
        :token => token })
      pullrequest.save
      return pullrequest
    end
    nil
  end


  def self.fetch_last_commit commits_url, token
    commits = Github.get_json "#{commits_url}?page=1&per_page=500", token
    commits.last
  rescue => e
    nil
  end


end
