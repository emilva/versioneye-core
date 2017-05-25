FROM        ruby:2.3.3
MAINTAINER  Robert Reiz <reiz@versioneye.com>

ENV RAILS_ENV enterprise
ENV BUNDLE_GEMFILE /app/Gemfile
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE=en_US.UTF-8

RUN apt-get update
RUN apt-get install -y libfontconfig1 # mandatory for PDFKit
RUN apt-get install -y supervisor;
RUN gem uninstall -i /usr/local/lib/ruby/gems/2.3.0 bundler -a -x
RUN gem install bundler --version 1.15.0
RUN rm -Rf /app; mkdir -p /app; mkdir -p /app/log; mkdir -p /app/pids

ADD . /app/

WORKDIR /app

RUN bundle update
