class VersionService < Versioneye::Service


  def self.equal(ver_1, ver_2)
    return true if ver_1.to_s.eql?( ver_2.to_s )

    sem_1 = SemVer.parse( ver_1 )
    sem_2 = SemVer.parse( ver_2 )
    if sem_1 && sem_2
      return sem_1 == sem_2
    end

    return false
  end


  def self.newest_version(versions, stability = 'stable')
    return nil if versions.nil? || versions.empty?

    filtered = Array.new
    versions.each do |version|
      next if version.to_s.eql?('dev-master')

      if VersionTagRecognizer.does_it_fit_stability? version.to_s, stability
        filtered << version
      end
    end
    filtered = versions if filtered.empty?
    if filtered.size > 1
      sorted = Naturalsorter::Sorter.sort_version_by_method( filtered, 'to_s', false )
      return sorted.first
    end
    return filtered.first
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    versions.first
  end


  def self.versions_by_whitelist(versions, whitelist)
    whitelist = Set.new whitelist.to_a
    versions.keep_if {|ver| whitelist.include? ver[:version]}
  end


  def self.newest_version_number( versions, stability = 'stable')
    version = newest_version( versions, stability )
    return nil if version.nil?
    return version.to_s
  end


  def self.newest_version_from( versions, stability = 'stable')
    return nil if versions.nil? || versions.empty?
    VersionService.newest_version( versions, stability )
  end


  def self.newest_version_from_wildcard( versions, version_start, stability = 'stable')
    version_start.gsub!(/x/i, "*")
    versions_filtered = versions_start_with( versions, version_start )
    return newest_version_number( versions_filtered, stability )
  end

  def self.newest_caret_version(versions, version_label)
      lower_border = caret_lower_border version_label
      upper_border = caret_upper_border version_label
      if lower_border.nil? or upper_border.nil?
        return version_label
      end

      greater_than = VersionService.greater_than_or_equal versions, lower_border, true
      newest_version = VersionService.smaller_than(greater_than, upper_border)
      if newest_version
        newest_version
      else
        version_label
      end
  end


  # http://guides.rubygems.org/patterns/#semantic_versioning
  # http://robots.thoughtbot.com/rubys-pessimistic-operator
  def self.version_approximately_greater_than_starter(value)
    ar      = value.split('.')
    new_end = ar.length - 2
    new_end = 0 if new_end < 0
    arr     = ar[0..new_end]
    starter = arr.join('.')
    return "#{starter}."
  end

  def self.version_tilde_newest( versions, value )
    return nil if value.nil?

    value = value.gsub('~', '')
    value = value.gsub(' ', '')
    upper_border = self.tile_border( value )
    greater_than = self.greater_than_or_equal( versions, value, true  )
    range = self.smaller_than( greater_than, upper_border, true )
    VersionService.newest_version_from( range )
  end

  def self.tile_border( value )
    if value.is_a? Integer
      return value + 1
    end
    if value.match(/\./).nil? && value.match(/^[0-9\-\_a-zA-Z]*\z/)
      return value.to_i + 1
    elsif value.match(/\./) && value.match(/^[0-9]+\.[0-9\-\_a-zA-Z]*\z/)
      nums  = value.split('.')
      up    = nums.first.to_i + 1
      return "#{up}.0"
    elsif value.match(/\./) && value.match(/^[0-9]+\.[0-9]+\.[0-9\-\_a-zA-Z]*\z/)
      nums = value.split('.')
      up   = nums[1].to_i + 1
      return "#{nums[0]}.#{up}"
    end
    nil
  end


  # Get all versions from range ( >=start <=stop )
  def self.version_range( versions, start, stop)
    range = Array.new
    versions.each do |version|
      fits_stop  = Naturalsorter::Sorter.smaller_or_equal?( version.to_s, stop  )
      fits_start = Naturalsorter::Sorter.bigger_or_equal?(  version.to_s, start )
      if fits_start && fits_stop
        range.push(version)
      end
    end
    range
  end


  # for wildcard version like 1.2.x or 1.2.*
  def self.wildcard_versions( versions, version, include_v = false )
    ver = version[0..version.length - 2]
    versions = VersionService.versions_start_with( versions, ver )
    versions << version[0..version.length - 3] if include_v == true
    versions
  end


  def self.versions_start_with( versions, val )
    return [] if versions.nil? || versions.empty?
    versions.dup.keep_if {|ver| ver[:version].to_s.match(/\A#{val}/)}
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    []
  end


  def self.newest_but_not( versions, value, range=false, stability = "stable")
    filtered_versions = versions.dup.keep_if {|version| version.to_s.match(/^#{value}/i).nil?}
    return filtered_versions if range

    newest = VersionService.newest_version_from(filtered_versions, stability)
    return get_newest_or_value(newest, value)
  end


  def self.greater_than( versions, value, range = false, stability = "stable")
    filtered_versions = Array.new
    versions.each do |version|
      if Naturalsorter::Sorter.bigger?(version.to_s, value)
        filtered_versions.push(version)
      end
    end
    return filtered_versions if range

    newest = VersionService.newest_version_from(filtered_versions, stability)
    return get_newest_or_value(newest, value)
  end


  def self.greater_than_or_equal( versions, value, range = false, stability = "stable")
    filtered_versions = Array.new
    versions.each do |version|
      if Naturalsorter::Sorter.bigger_or_equal?(version.to_s, value)
        filtered_versions.push(version)
      end
    end
    return filtered_versions if range

    newest = VersionService.newest_version_from(filtered_versions, stability)
    return get_newest_or_value(newest, value)
  end


  def self.smaller_than( versions, value, range = false, stability = "stable")
    filtered_versions = Array.new
    versions.each do |version|
      if Naturalsorter::Sorter.smaller?(version.to_s, value.to_s)
        filtered_versions.push(version)
      end
    end
    return filtered_versions if range

    newest = VersionService.newest_version_from(filtered_versions, stability)
    return get_newest_or_value(newest, value)
  end


  def self.smaller_than_or_equal( versions, value, range = false, stability = "stable")
    filtered_versions = Array.new
    versions.each do |version|
      if Naturalsorter::Sorter.smaller_or_equal?(version.to_s, value)
        filtered_versions.push(version)
      end
    end
    return filtered_versions if range

    newest = VersionService.newest_version_from(filtered_versions, stability)
    return get_newest_or_value(newest, value)
  end

  #nuget allows to specify version by combining greater_than and smaller_than
  def self.intersect_versions(versions1, versions2, range = true)
    all_versions = versions1.to_a.concat versions2.to_a
    common_version_labels = Set.new(versions1.to_a.map(&:version)) & Set.new(versions2.to_a.map(&:version))
    common_versions = all_versions.keep_if do |ver|
      result = false
      if common_version_labels.include? ver[:version]
        common_version_labels.delete ver[:versions]
        result = true
      end
      result
    end

    return newest_version(common_versions) unless range #return only the latest version
    common_versions
  end

  # For ranges like "<3.11 || >= 4 <4.5"
  def self.from_or_ranges( versions, version_string, separator = '||')
    filtered_versions = []
    sps = version_string.split(separator)
    sps.each do |vs|
      v = clean_range vs.strip
      v = v.gsub(/\s+/, ",")
      filtered = from_ranges(versions, v)
      filtered.each do |ver|
        filtered_versions << ver
      end
    end
    filtered_versions
  end

  def self.clean_range version_string
    expr = version_string.gsub("> ", ">")
    expr = expr.gsub("< ", "<")
    expr = expr.gsub("= ", "=")
    expr = expr.gsub("~ ", "~")
    expr
  end


  # returns common_range which is version that match all the selectors
  # params:
  #   product_versions - version models from Product.versions field
  #   version_label    - string, '>= 0.3, < 0.7'
  #   range            - boolean, true = it returns whole range, false = only the highest
  #   separator        - string, character which is used to separate different selectors
  def self.from_common_range(product_versions, version_label, range = true, separator = ',')
    ranges = []
    version_label.to_s.split(separator).each do |version_range|
      ranges << VersionService.from_ranges(product_versions, version_range)
    end

    common_range = ranges.to_a.reduce(product_versions) do |intersection, range_ |
      VersionService.intersect_versions(intersection, range_ , true)
    end

    #return a versions that match all the selectors or only highest
    if range
      common_range
    else
      VersionService.newest_version(common_range)
    end
  end


  # Returns an Array sub range from a version constraint string.
  # Examples for version_string:
  #   >=1.0, <1.2
  #   2.0.X, 2.1.X
  #   ~> 2.0.0
  #   <=2.7.1
  def self.from_ranges( versions, version_string )
    version_splitted = version_string.split(",")
    prod = Product.new
    prod.versions = []
    version_splitted.each do |verso|
      verso.gsub!(" ", "")
      stability = VersionTagRecognizer.stability_tag_for verso

      # >=
      if verso.match(/\A>=/)
        verso.gsub!(">=", "")
        version_array = prod.versions.empty? ? versions : prod.versions
        new_range = VersionService.greater_than_or_equal( version_array, verso, true, stability )
        prod.versions = new_range

      # >
      elsif verso.match(/\A>/)
        verso.gsub!(">", "")
        version_array = prod.versions.empty? ? versions : prod.versions
        new_range = VersionService.greater_than( version_array, verso, true, stability )
        prod.versions = new_range

      # <=
      elsif verso.match(/\A<=/)
        verso.gsub!("<=", "")
        version_array = prod.versions.empty? ? versions : prod.versions
        new_range = VersionService.smaller_than_or_equal( version_array, verso, true, stability )
        prod.versions = new_range

      # <
      elsif verso.match(/\A</)
        verso.gsub!("<", "")
        version_array = prod.versions.empty? ? versions : prod.versions
        new_range = VersionService.smaller_than( version_array, verso, true, stability )
        prod.versions = new_range

      # ~> | Approximately greater than | Pessimistic Version Constraint
      elsif verso.match(/\A~>/)
        ver = verso.gsub("~>", "")
        ver = ver.gsub(" ", "")
        starter   = VersionService.version_approximately_greater_than_starter( ver )
        new_range = VersionService.versions_start_with( versions, starter )
        new_range.each do |version|
          prod.versions.push version
        end

      # !=
      elsif verso.match(/\A!=/)
        verso.gsub!("!=", "")
        version_array = prod.versions.empty? ? versions : prod.versions
        new_range = VersionService.newest_but_not( version_array, verso, true, stability)
        prod.versions = new_range

      # = or ==
      elsif verso.match(/\A==/) || verso.match(/\A=/) || verso.match(/\A\w/)
        verso = verso.gsub(/\A==/, "").gsub(/\A=/, "")
        if verso.match(/\.x\z/i) || verso.match(/\.\*\z/i)
          new_versions = VersionService.wildcard_versions( versions, verso )
          new_versions.each do |version|
            prod.versions << version
          end
        else
          versions.each do |version|
            prod.versions << version if version.to_s.eql?(verso)
          end
        end
      end
    end
    prod.versions
  end

  # turns caret semver selector into lower version
  # returns:
  # nil - failed to parse semver
  # string - lower range of caret version
  def self.caret_lower_border(version_label)
    lower_ver = SemVer.parse version_label
    return nil if lower_ver.nil?
    #remove metdata details
    lower_ver.metadata = nil
    lower_ver.prerelease = nil

    lower_ver.to_s
  end

  # calculates upper version of caret semver
  # it increments most left-most non-zero value
  # returns:
  # nil - failed to parse semver
  # string - upper range of caret version
  def self.caret_upper_border(version_label)
    upper_ver = SemVer.parse version_label
    return nil if upper_ver.nil?

    #remove metdata and pre-release details
    upper_ver.metadata = nil
    upper_ver.prerelease = nil

    #increase left-most non-zero version item
    if upper_ver.major != 0
      upper_ver.major += 1
      upper_ver.minor = 0
      upper_ver.patch = 0
    elsif upper_ver.major == 0 and upper_ver.minor != 0
      upper_ver.minor += 1
      upper_ver.patch = 0
    else
      if upper_ver.patch != 0
        upper_ver.patch += 1
      else
        upper_ver.major += 1 #when version is '0.0.0'
      end
    end

    upper_ver.to_s
  end

  def self.average_release_time( versions )
    return nil if versions.nil? || versions.empty? || versions.size == 1

    released_versions = versions.find_all{ |version| version.released_at }
    return nil if released_versions.nil? || released_versions.empty? || released_versions.size < 3

    sorted_versions = released_versions.sort! { |a,b| a.released_at <=> b.released_at }
    first = sorted_versions.first.released_at
    last  = sorted_versions.last.released_at
    return nil if first.nil? || last.nil?

    diff = last.to_i - first.to_i
    diff_days = diff / 60 / 60 / 24
    (diff_days.to_f / sorted_versions.size.to_f).round
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def self.estimated_average_release_time( versions )
    return nil if versions.nil? || versions.empty? || versions.size == 1

    sorted_versions = versions.sort! { |a,b| a.created_at <=> b.created_at }
    first = sorted_versions.first.created_at
    last  = sorted_versions.last.created_at
    return nil if first.nil? || last.nil?

    diff = last.to_i - first.to_i
    diff_days = diff / 60 / 60 / 24
    average = diff_days / sorted_versions.size
    average
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  private

    def self.get_newest_or_value(newest, value)
      return Version.new({:version => value}) if newest.nil?
      return newest
    end

end
