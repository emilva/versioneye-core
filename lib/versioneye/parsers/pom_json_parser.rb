require 'versioneye/parsers/common_parser'
require 'versioneye/parsers/pom_parser'

class PomJsonParser < PomParser


  def parse(url)
    return nil if url.nil? || url.empty?

    response = self.fetch_response( url )
    return nil if response.nil?
    return nil if response.code.to_i != 200 && response.code.to_i != 201

    parse_content response.body
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def parse_content( content, token = nil )
    return nil if content.to_s.empty?
    return nil if content.to_s.strip.eql?('Not Found')

    pom_json = JSON.parse( content )
    return nil if pom_json.nil?

    project = Project.new({:project_type => Project::A_TYPE_MAVEN2, :language => Product::A_LANGUAGE_JAVA })
    project.name         = pom_json['name']
    project.group_id     = pom_json['group_id']
    project.artifact_id  = pom_json['artifact_id']
    project.version      = pom_json['version']
    project.project_type = pom_json['prod_type'] if !pom_json['prod_type'].to_s.empty?
    project.language     = pom_json['language']  if !pom_json['language'].to_s.empty?
    project.license      = fetch_license( pom_json )
    uniq_deps = []
    pom_json['dependencies'].each do |json_dep|
      version     = json_dep['version']
      version     = version.to_s.gsub(/-redhat-.*/i, "")
      name        = json_dep['name']
      scope       = json_dep['scope']
      scope       = 'compile' if scope.to_s.empty?

      uniq_key    = "#{name}:#{version}:#{scope}"
      if !uniq_deps.include?( uniq_key )
        uniq_deps << uniq_key
      else
        next
      end

      spliti      = name.split(':')
      group_id    = spliti[0].to_s.downcase
      artifact_id = spliti[1].to_s.downcase
      dependency  = init_dependency(name, group_id, artifact_id, version, scope)
      product     = Product.find_by_group_and_artifact( dependency.group_id, dependency.artifact_id )
      parse_requested_version(version, dependency, product)
      dependency.prod_key     = product.prod_key if product
      project.unknown_number += 1 if product.nil?
      project.out_number     += 1 if ProjectdependencyService.outdated?( dependency )
      project.projectdependencies.push(dependency)
    end
    project.dep_number   = project.dependencies.size
    project
  end


  def init_dependency name, group_id, artifact_id, version, scope
    dependency                   = Projectdependency.new
    dependency.language          = Product::A_LANGUAGE_JAVA
    dependency.name              = name
    dependency.group_id          = group_id
    dependency.artifact_id       = artifact_id
    dependency.version_requested = version
    dependency.version_label     = version
    dependency.scope             = scope
    dependency
  end


  private


    def fetch_license pom_json
      licenses = pom_json['licenses']
      return nil if licenses.to_s.empty?

      if licenses.is_a? Array
        return licenses.map { |lic| "#{lic['name']}" }.join(", ")
      elsif licenses.is_a? String
        return licenses
      end
      nil
    end

end
