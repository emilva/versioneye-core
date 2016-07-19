class GithubPullRequestService < Versioneye::Service

  # commits_url + branch + number
  # project + token
  # set status to pending
  # Check async
  # - set status to success | error

  def self.process project_id, commits_url, pr_nr, branch
    log.info "process #{project_id}, #{commits_url}"

    project   = Project.find project_id
    token     = GithubUpdater.new.fetch_token_for project
    repo_name = project.scm_fullname
    filename  = project.s3_filename
    sha       = fetch_sha commits_url, token

    project_file = Github.fetch_project_file_from_branch(repo_name, filename, branch, token, sha )
    new_project  = ProjectImportService.create_project_from project_file, token
    ProjectdependencyService.update_security new_project
    log.info " #{commits_url} - sv_count: #{new_project.sv_count} - project.id is #{new_project.ids}"
    new_project.temp = true
    new_project.save

    # TODO do more checks and update status on pull request

    'Done'
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
  end


  def self.fetch_sha commits_url, token
    commits  = Github.get_json commits_url, token
    last_commit = commits.last
    last_commit[:commit][:tree][:sha]
  end


end