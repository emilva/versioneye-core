module Versioneye
  class Service

    require 'versioneye/log'
    require 'versioneye/cache'
    require 'versioneye/etcd_client'

    require 'versioneye/services/auth_service'
    require 'versioneye/services/analytics_service'
    require 'versioneye/services/author_service'
    require 'versioneye/services/badge_service'
    require 'versioneye/services/badge_ref_service'
    require 'versioneye/services/bitbucket_service'
    require 'versioneye/services/stash_service'
    require 'versioneye/services/circle_element_service'
    require 'versioneye/services/dependency_service'
    require 'versioneye/services/git_hub_service'
    require 'versioneye/services/github_pull_request_service'
    require 'versioneye/services/http_service'
    require 'versioneye/services/notification_service'
    require 'versioneye/services/newsletter_service'
    require 'versioneye/services/newest_service'
    require 'versioneye/services/organisation_service'
    require 'versioneye/services/product_service'
    require 'versioneye/services/project_service'
    require 'versioneye/services/project_import_service'
    require 'versioneye/services/project_update_service'
    require 'versioneye/services/project_batch_update_service'
    require 'versioneye/services/project_parse_service'
    require 'versioneye/services/projectdependency_service'
    require 'versioneye/services/receipt_service'
    require 'versioneye/services/security_notification_service'
    require 'versioneye/services/statistic_service'
    require 'versioneye/services/submitted_url_service'
    require 'versioneye/services/team_service'
    require 'versioneye/services/user_service'
    require 'versioneye/services/admin_service'
    require 'versioneye/services/version_service'
    require 'versioneye/services/email_setting_service'
    require 'versioneye/services/reference_service'
    require 'versioneye/services/language_service'
    require 'versioneye/services/ldap_service'
    require 'versioneye/services/component_whitelist_service'
    require 'versioneye/services/license_whitelist_service'
    require 'versioneye/services/license_service'
    require 'versioneye/services/lwl_service'
    require 'versioneye/services/lwl_pdf_service'
    require 'versioneye/services/lwl_csv_service'
    require 'versioneye/services/sec_pdf_service'
    require 'versioneye/services/sync_service'
    require 'versioneye/services/transfer_service'
    require 'versioneye/services/enterprise_service'
    require 'versioneye/services/scm_meta_data_service'
    require 'versioneye/services/team_notification_service'

    require 'versioneye/services_ext/bitbucket'
    require 'versioneye/services_ext/stash'
    require 'versioneye/services_ext/es_product'
    require 'versioneye/services_ext/github'
    require 'versioneye/services_ext/mongo_product'
    require 'versioneye/services_ext/octokit_api'
    require 'versioneye/services_ext/s3'
    require 'versioneye/services_ext/stripe_service'

    require 'versioneye/mailers/super_mailer'
    require 'versioneye/mailers/notification_mailer'
    require 'versioneye/mailers/feedback_mailer'
    require 'versioneye/mailers/newsletter_mailer'
    require 'versioneye/mailers/project_mailer'
    require 'versioneye/mailers/submitted_url_mailer'
    require 'versioneye/mailers/subscription_mailer'
    require 'versioneye/mailers/user_mailer'
    require 'versioneye/mailers/receipt_mailer'
    require 'versioneye/mailers/versioncomment_mailer'
    require 'versioneye/mailers/versioncommentreply_mailer'
    require 'versioneye/mailers/team_mailer'

    require 'versioneye/parsers/berksfile_parser'
    require 'versioneye/parsers/berksfilelock_parser'
    require 'versioneye/parsers/metadata_parser'
    require 'versioneye/parsers/biicode_parser'
    require 'versioneye/parsers/bower_parser'
    require 'versioneye/parsers/common_parser'
    require 'versioneye/parsers/composer_lock_parser'
    require 'versioneye/parsers/composer_parser'
    require 'versioneye/parsers/gemfile_parser'
    require 'versioneye/parsers/gemfilelock_parser'
    require 'versioneye/parsers/gradle_parser'
    require 'versioneye/parsers/sbt_parser'
    require 'versioneye/parsers/lein_parser'
    require 'versioneye/parsers/package_parser'
    require 'versioneye/parsers/parser_strategy'
    require 'versioneye/parsers/podfile_parser'
    require 'versioneye/parsers/podfilelock_parser'
    require 'versioneye/parsers/pom_json_parser'
    require 'versioneye/parsers/pom_parser'
    require 'versioneye/parsers/python_setup_parser'
    require 'versioneye/parsers/requirements_parser'
    require 'versioneye/parsers/scm_changelog_parser'
    require 'versioneye/parsers/nuget_parser'
    require 'versioneye/parsers/paket_parser'
    require 'versioneye/parsers/nuget_json_parser'
    require 'versioneye/parsers/nuget_packages_parser'
    require 'versioneye/parsers/godep_parser'
    require 'versioneye/parsers/cpan_parser'
    require 'versioneye/parsers/gemspec_parser'

    require 'versioneye/updaters/update_strategy'
    require 'versioneye/updaters/common_updater'
    require 'versioneye/updaters/bitbucket_updater'
    require 'versioneye/updaters/github_updater'
    require 'versioneye/updaters/stash_updater'
    require 'versioneye/updaters/upload_updater'
    require 'versioneye/updaters/url_updater'

    require 'versioneye/remote_api/common_client'
    require 'versioneye/remote_api/security_client'
    require 'versioneye/remote_api/product_client'
    require 'versioneye/remote_api/me_client'

    require 'versioneye/migrations/product_migration'
    require 'versioneye/migrations/project_orga_migration'

    require 'versioneye/producers/producer.rb'
    require 'versioneye/producers/html_worker_producer.rb'
    require 'versioneye/producers/dependency_badge_producer.rb'
    require 'versioneye/producers/git_repo_file_import_producer.rb'
    require 'versioneye/producers/git_repos_import_producer.rb'
    require 'versioneye/producers/git_repo_import_producer.rb'
    require 'versioneye/producers/language_daily_stats_producer.rb'
    require 'versioneye/producers/project_update_producer.rb'
    require 'versioneye/producers/update_meta_data_producer.rb'
    require 'versioneye/producers/update_index_producer.rb'
    require 'versioneye/producers/send_notification_emails_producer.rb'
    require 'versioneye/producers/process_receipts_producer.rb'
    require 'versioneye/producers/common_producer.rb'
    require 'versioneye/producers/sync_producer.rb'
    require 'versioneye/producers/mvn_html_worker_producer.rb'
    require 'versioneye/producers/mvn_index_worker_producer.rb'
    require 'versioneye/producers/notification_queue_producer.rb'
    require 'versioneye/producers/team_notification_producer.rb'

    require 'versioneye/workers/worker.rb'
    require 'versioneye/workers/dependency_badge_worker.rb'
    require 'versioneye/workers/git_repo_file_import_worker.rb'
    require 'versioneye/workers/git_repos_import_worker.rb'
    require 'versioneye/workers/git_repo_import_worker.rb'
    require 'versioneye/workers/language_daily_stats_worker.rb'
    require 'versioneye/workers/project_update_worker.rb'
    require 'versioneye/workers/update_meta_data_worker.rb'
    require 'versioneye/workers/update_index_worker.rb'
    require 'versioneye/workers/send_notification_emails_worker.rb'
    require 'versioneye/workers/process_receipts_worker.rb'
    require 'versioneye/workers/common_worker.rb'
    require 'versioneye/workers/sync_worker.rb'
    require 'versioneye/workers/team_notification_worker.rb'

    require 'versioneye/importers/sap_team_user_importer.rb'

    def self.log
      Versioneye::Log.instance.log
    end

    def self.logger
      Versioneye::Log.instance.log
    end

    def log
      Versioneye::Log.instance.log
    end

    def logger
      Versioneye::Log.instance.log
    end

    def self.cache
      Versioneye::Cache.instance.mc
    end

    def cache
      Versioneye::Cache.instance.mc
    end

    def self.etcd
      Versioneye::EtcdClient.instance.etcd
    end

    def etcd
      Versioneye::EtcdClient.instance.etcd
    end

  end

end
