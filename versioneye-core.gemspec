$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'versioneye/version'

Gem::Specification.new do |s|
  s.name             = "versioneye-core"
  s.version          = Versioneye::VERSION
  s.require_paths    = ["lib"]
  s.authors          = ['Robert Reiz']
  s.email            = "robert.reiz.81@gmail.com"
  s.homepage         = "http://github.com/versioneye/versioneye-core"
  s.license          = "MIT"
  s.summary          = "Models & Services for VersionEye"
  s.description      = "This project contains the Models and Services for VersionEye"
  s.extra_rdoc_files = ['LICENSE.txt', 'README.md']
  s.files            = `git ls-files -z`.split("\0")

  s.add_runtime_dependency 'bundler', '~> 1.13.0'
  s.add_runtime_dependency 'naturalsorter', '~> 3.0.14'
  s.add_runtime_dependency 'dalli', '~> 2.7.6'
  s.add_runtime_dependency 'oauth', '~> 0.5.0'
  s.add_runtime_dependency 'aws-sdk', '~> 2.6.19'
  s.add_runtime_dependency 'stripe', '~> 1.57.0'
  s.add_runtime_dependency 'tire', '~> 0.6.2'
  s.add_runtime_dependency 'octokit', '~> 4.6.0'
  s.add_runtime_dependency 'semverly', '~> 1.0.0'
  s.add_runtime_dependency 'httparty', '~> 0.14.0'
  s.add_runtime_dependency 'persistent_httparty', '~> 0.1.0'
  s.add_runtime_dependency 'nokogiri', '~> 1.6.8'
  # TODO: comment out when official core will support activesupport5
  # meanwhile it will use forked version defined in Gemfile
  #  s.add_runtime_dependency 'cocoapods-core', '~> 1.1'
  s.add_runtime_dependency 'actionmailer', '~> 5.0.0.1'
  s.add_runtime_dependency 'pdfkit', '~> 0.8.2'
  s.add_runtime_dependency 'bunny', '~> 2.6.0'
  s.add_runtime_dependency 'wkhtmltopdf-binary', '~> 0.12.3'
  s.add_runtime_dependency 'etcd', '~> 0.3.0'
  s.add_runtime_dependency 'mongoid', '~> 6.0.0'
  s.add_runtime_dependency 'will_paginate_mongoid', '= 2.0.1'
  s.add_runtime_dependency 'net-ldap', '~> 0.15.0'
  s.add_runtime_dependency 'gemnasium-parser', '~> 0.1.9'
end
