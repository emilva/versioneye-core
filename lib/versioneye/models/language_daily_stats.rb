class LanguageDailyStats < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  field :language, type: String
  field :date, type: DateTime
  field :date_string, type: String #format: %Y-%m-%d

  field :Clojure   , type: Hash
  field :Java      , type: Hash
  field :Javascript, type: Hash
  field :Nodejs    , type: Hash
  field :Php       , type: Hash
  field :Python    , type: Hash
  field :R         , type: Hash
  field :Ruby      , type: Hash
  field :Objectivec, type: Hash
  field :Rust      , type: Hash
  field :Perl      , type: Hash
  field :Elixir    , type: Hash

  index({date: -1},        {background: true})
  index({date_string: -1}, {background: true})
  index({created_at: -1},  {background: true})


  def self.initial_metrics_table
    {
      'new_version'    => 0, # new   versions  publised
      'novel_package'  => 0, # new   libraries published
      'total_package'  => 0, # total packages  upto this date
      'total_artifact' => 0  # total artifacts upto this date
    }
  end


  def self.update_counts(ndays = 1, skip = 0)
    ndays += skip
    ndays.times do |n|
      next if n < skip
      self.update_day_stats(n)
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def initialize_metrics_tables
    Product::A_LANGS_SUPPORTED.each do |lang|
      lang_key       = LanguageDailyStats.language_to_sym( lang )
      self[lang_key] = LanguageDailyStats.initial_metrics_table
    end
  end


  def self.language_to_sym(lang)
    lang = Product.encode_language(lang).capitalize
    lang = lang.gsub(/\-/, '') # Special rule for Objective-C
    lang = lang.gsub(/\./, '') # Special rule for Node.JS
    lang.to_sym
  end


  def self.to_date_string(that_day)
    that_day.strftime('%Y-%m-%d')
  end


  def self.new_document(that_day = DateTime.now, save = false)
    day_string = self.to_date_string(that_day)
    self.where(date_string: day_string).delete_all # remove previous document

    new_doc  = LanguageDailyStats.new date: that_day.at_midnight
    new_doc[:date_string] = self.to_date_string(that_day)
    new_doc.initialize_metrics_tables

    new_doc.save if save
    new_doc
  end


  def self.update_day_stats( n )
    that_day = n.days.ago.at_beginning_of_day
    that_day_doc = self.new_document(that_day, false)
    that_day_doc.count_releases
    that_day_doc.count_language_packages
    that_day_doc.count_language_artifacts
    that_day_doc.save
  end


  def count_releases
    that_day = self[:date]
    next_day = (that_day + 1.day)
    that_day_releases = Newest.since_to( that_day.at_midnight, next_day.at_midnight )
    return if that_day_releases.nil? || that_day_releases.empty?

    that_day_releases.each do |release|
      self.count_release( release )
    end
  end


  def count_release(release)
    if release[:language].nil? || release[:language].empty?
      LanguageDailyStats.log.error("Product #{release[:prod_key]} misses language")
      return nil
    end

    language = normalize_language release[:language]
    if !Product::A_LANGS_SUPPORTED.include?(language)
      LanguageDailyStats.log.warn("Product #{release[:prod_key]} language #{language} is not supported.")
      return nil
    end

    metric_key = LanguageDailyStats.language_to_sym( language )
    self.inc_version( metric_key )

    that_day_midnight = self[:date].at_midnight
    next_day_midnight = that_day_midnight + 1.day
    count = Product.where(:language => language, :prod_key => release.prod_key,
      :created_at.gte => that_day_midnight, :created_at.lte => next_day_midnight).count

    self.inc_novel(metric_key) if count > 0
  end


  def count_language_packages
    that_day = self[:date]
    Product::A_LANGS_SUPPORTED.each do |lang|
      lang_total = Product.by_language(lang).where(:created_at.lt => that_day.at_midnight).count
      language_key = LanguageDailyStats.language_to_sym(lang)
      self.inc_total_package(language_key, lang_total)
    end
  end


  def count_language_artifacts
    that_day = self[:date]
    Product::A_LANGS_SUPPORTED.each do |lang|
      n_artifacts = 0

      language_key = LanguageDailyStats.language_to_sym(lang)
      n_artifacts  = LanguageDailyStats.count_artifacts( lang, that_day )
      self.inc_total_artifact(language_key, n_artifacts)
    end
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end


  def self.count_artifacts language, until_date
    ag = Product.collection.aggregate(
      [
      { '$unwind' => "$versions" },
      { '$match' => {'language' => "#{language}", 'versions.created_at' => {'$lte': until_date } } },
      { '$group' => { '_id' => '', 'count' => {'$sum' => 1} } }
      ]
    )
    return ag.first["count"] if ag && ag.first
    return 0
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    0
  end


  def inc_version(metric_key, val = 1)
    self[metric_key]['new_version'] += val
  end


  def inc_novel(metric_key, val =  1)
    self[metric_key]['novel_package'] += val
  end


  def inc_total_package(metric_key, val =  1)
    self[metric_key]['total_package'] += val
  end


  def inc_total_artifact(metric_key, val = 1)
    self[metric_key]['total_artifact'] += val
  end


  def metrics
    doc = self.attributes
    langs_keys = []
    Product::A_LANGS_SUPPORTED.each {|lang| langs_keys << LanguageDailyStats.language_to_sym(lang)}
    doc.keep_if {|key, val| langs_keys.include?(key.to_sym)}
  end


  #shows only metrics of Stats doc
  def self.doc_metrics(doc)
    if doc.nil?
      log.warn("It tried to read not existing todays stat - returning new empty doc.")
      doc = self.new_document(Date.today)
    end
    doc.metrics
  end


  def self.combine_docs(docs)
    stats = {}
    docs.each do |doc|
      doc_stats = LanguageDailyStats.doc_metrics(doc)
      stats.merge!(doc_stats) do |lang_key, doc1, doc2|
        doc1 ||= {}
        doc1.merge(doc2) {|metric, oldval, newval| oldval + newval}
      end
    end

    stats
  end


  #-- query helpers
  def self.latest_stats(lang = "Ruby")
    lang_key = LanguageDailyStats.language_to_sym(lang)
    doc = LanguageDailyStats.where(:"#{lang_key.to_s}.total_artifact".gt => 0).desc(:date).first
    self.doc_metrics(doc)
  end


  def self.since_to(dt_since, dt_to)
    self.where(:date.gte => dt_since, :date.lt => dt_to).desc(:date)
  end


  def self.today_stats
    dt_string = LanguageDailyStats.to_date_string(Date.today)
    doc = self.where(date_string: dt_string).shift
    self.doc_metrics(doc)
  end


  def self.yesterday_stats
    dt_string = LanguageDailyStats.to_date_string(1.day.ago)
    doc = self.where(date_string: dt_string).shift
    self.doc_metrics(doc)
  end


  #stats for 2days ago
  def self.t2_stats
    dt_string = LanguageDailyStats.to_date_string(2.day.ago)
    doc = self.where(date_string: dt_string).shift
    self.doc_metrics(doc)
  end


  def self.current_week_stats
    dt_since = Date.today.at_beginning_of_week
    dt_to    = DateTime.now
    rows = self.since_to(dt_since, dt_to)
    self.combine_docs(rows)
  end

  def self.last_week_stats
    dt_monday      = Date.today.at_beginning_of_week
    dt_prev_monday = dt_monday - 7
    rows = self.since_to(dt_prev_monday, dt_monday)
    self.combine_docs(rows)
  end


  def self.current_month_stats
    dt_since = Date.today.at_beginning_of_month
    dt_to    = DateTime.now
    rows = self.since_to(dt_since, dt_to)
    self.combine_docs(rows)
  end

  def self.last_30_days_stats
    self.since_to(30.days.ago.at_midnight, Date.tomorrow.at_midnight).asc(:date)
  end

  def self.last_month_stats
    month_ago = Date.today << 1
    rows      = self.since_to(month_ago.at_beginning_of_month, Date.today.at_beginning_of_month)
    self.combine_docs(rows)
  end

  def self.two_months_ago_stats
    month_ago      = Date.today << 1
    two_months_ago = Date.today << 2
    rows           = self.since_to(two_months_ago.at_beginning_of_month, month_ago.at_beginning_of_month)
    self.combine_docs(rows)
  end

  #-- response helpers

  def self.to_metric_response(metric, t0_stats, t1_stats)
    rows = []

    Product::A_LANGS_SUPPORTED.each do |lang|
      lang_key = LanguageDailyStats.language_to_sym(lang).to_s

      t0_metric_value = t0_stats.has_key?(lang_key) ? t0_stats[lang_key][metric] : nil
      t1_metric_value = t1_stats.has_key?(lang_key) ? t1_stats[lang_key][metric] : nil
      if t0_metric_value and t1_metric_value
        diff = t0_metric_value - t1_metric_value
      else
        diff  = 0
      end

      rows << {
        title: lang,
        value: t0_metric_value || 0,
        t1: diff
      }
    end
    rows.sort_by {|row| row[:title]}
  end

  def self.get_time_span(time_span)
    case time_span
    when :today
      t1 = self.today_stats
      t2 = self.yesterday_stats
    when :yesterday
      t1 = self.yesterday_stats
      t2 = self.t2_stats
    when :current_week
      t1 = self.current_week_stats
      t2 = self.last_week_stats
    when :current_month
      t1 = self.current_month_stats
      t2 = self.last_month_stats
    when :last_month
      t1 = self.last_month_stats
      t2 = self.two_months_ago_stats
    else
      t1 = self.yesterday_stats
      t2 = self.t2_stats
    end
    return t1, t2
  end

  def self.latest_versions(time_span)
    t1, t2 = get_time_span(time_span)
    self.to_metric_response('new_version', t1, t2)
  end

  def self.novel_releases(time_span)
    t1, t2 = get_time_span(time_span)
    self.to_metric_response('novel_package', t1, t2)
  end

  def self.language_timeline30(lang, metric)
    rows = self.last_30_days_stats
    results = []
    return results if rows.nil? || rows.empty?

    lang_key = LanguageDailyStats.language_to_sym(lang)
    rows.each do |row|
      val = 0
      val = row[lang_key][metric] if row.has_attribute?(lang_key)

      results << {
        title: lang,
        value: val || 0,
        date: row[:date_string]
      }
    end
    results
  end

  def self.versions_timeline30(lang)
    self.language_timeline30(lang, 'new_version')
  end

  def self.novel_releases_timeline30(lang)
    self.language_timeline30(lang, 'novel_package')
  end

  private

    # In the UI all variants of JavaScript are bundled/displayed as JavaScript!
    def normalize_language lang
      return Product::A_LANGUAGE_JAVASCRIPT if lang.eql?("PureScript")
      return Product::A_LANGUAGE_JAVASCRIPT if lang.eql?("CoffeeScript")
      return Product::A_LANGUAGE_JAVASCRIPT if lang.eql?("ActionScript")
      return Product::A_LANGUAGE_JAVASCRIPT if lang.eql?("TypeScript")
      return Product::A_LANGUAGE_JAVASCRIPT if lang.eql?("LiveScript")
      return lang
    end

end
