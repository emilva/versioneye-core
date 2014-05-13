class ProjectImportService < Versioneye::Service


=begin
  This methods is
   - Importing a project_file from GitHub
   - Parsing the project_file to a new project
   - Storing the new project to DB
=end
  def self.import_from_github user, repo_name, filename, branch = 'master'
    private_project = Github.private_repo? user.github_token, repo_name
    unless allowed_to_add_project?(user, private_project)
      return "Please upgrade your plan to monitor the selected project."
    end

    project_file = Github.fetch_project_file_from_branch(repo_name, filename, branch, user[:github_token] )
    if project_file.nil?
      log.error " Can't import project file `#{filename}` from #{repo_name} branch #{branch} "
      return " Didn't find any project file of a supported package manager."
    end

    file_bin = project_file[:content]
    file_txt = Base64.decode64(file_bin)

    full_name = project_file[:name]
    file_name = full_name.split("/").last

    parser  = ProjectParseService.parser_for file_name
    project = ProjectParseService.parse_content parser, file_txt, file_name

    project.update_attributes({
      name: repo_name,
      project_type: project_file[:type],
      user_id: user.id.to_s,
      source: Project::A_SOURCE_GITHUB,
      private_project: private_project,
      scm_fullname: repo_name,
      scm_branch: branch,
      s3_filename: filename,
      url: project_file[:url]
    })

    return project if ProjectService.store( project )
    return nil
  end


=begin
  This methods is
   - Importing a project_file from Bitbucket
   - Parsing the project_file to a new project
   - Storing the new project to DB
=end
  def self.import_from_bitbucket(user, repo_name, filename, branch = "master")
    repo = BitbucketRepo.by_user(user).by_fullname(repo_name).shift
    private_project = repo[:private]
    unless allowed_to_add_project?(user, private_project)
      return "Please upgrade your plan to monitor the selected project."
    end

    project_file = Bitbucket.fetch_project_file_from_branch(
      repo_name, branch, filename,
      user[:bitbucket_token], user[:bitbucket_secret]
    )

    if project_file.nil? || project_file == "error" || project_file.eql?("Not Found")
      log.error " Can't import project file `#{filename}` from #{repo_name} branch #{branch} "
      return " Didn't find any project file of a supported package manager."
    end

    project_type = ProjectService.type_by_filename filename
    file_name = filename.split("/").last
    parser  = ProjectParseService.parser_for file_name
    project = ProjectParseService.parse_content parser, project_file, file_name

    project.update_attributes({
      name: repo_name,
      project_type: project_type,
      user_id: user.id.to_s,
      source: Project::A_SOURCE_BITBUCKET,
      scm_fullname: repo_name,
      scm_branch: branch,
      private_project: private_project,
      s3_filename: filename,
      url: nil
    })

    return project if ProjectService.store( project )
    return nil
  end


  def self.import_from_url( url, project_name, user )
    project = build_from_url( url )
    return nil if project.nil?

    if project.name.nil? || project.name.empty?
      project.name = project_name
    end

    project.update_attributes({
      user_id: user.id.to_s,
      source: Project::A_SOURCE_URL,
      s3_filename: project_name,
      url: url
    })

    return project if ProjectService.store( project )
    return nil
  end


  def self.import_from_upload file, user = nil, api_created = false
    project_name = file['datafile'].original_filename
    content      = file['datafile'].read

    parser  = ProjectParseService.parser_for project_name
    project = ProjectParseService.parse_content parser, content, project_name

    project.s3_filename = project_name
    project.name        = project_name
    project.source      = Project::A_SOURCE_UPLOAD
    project.user        = user
    project.api_created = api_created

    return project if ProjectService.store( project )
    return nil
  end


  private


    def self.allowed_to_add_project?( user, private_project )
      return true if !private_project
      return true if Settings.instance.projects_unlimited

      private_project_count = Project.private_project_count_by_user( user.id )
      max = user.free_private_projects
      if user.plan
        max += user.plan.private_projects
      end
      return false if private_project_count >= max
      return true
    end


    def self.build_from_url(url, project_type = nil)
      project_type = ProjectService.type_by_filename(url) if project_type.nil?
      parser       = ParserStrategy.parser_for( project_type, url )
      parser.parse url
    rescue => e
      log.error "Error in build_from_url( #{url} ) -> #{e.message}"
      log.error e.backtrace.join("\n")
      nil
    end


end
