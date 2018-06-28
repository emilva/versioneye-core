[![CircleCI](https://circleci.com/gh/versioneye/versioneye-core.svg?style=svg)](https://circleci.com/gh/versioneye/versioneye-core) [![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Femilva%2Fversioneye-core.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Femilva%2Fversioneye-core?ref=badge_shield)


# versioneye-core

This project contains the core elements of [VersionEye](https://www.versioneye.com).

 - Models & Persistence
 - Services
 - Mailers
 - Parsers
 - RabbitMQ Producers & Workers

This project is used as a dependency in all other Ruby projects of [VersionEye](https://www.versioneye.com).

This project is setup and managed with [jeweler](https://www.versioneye.com/ruby/jeweler).
A great Ruby project to manage a Ruby Gem project.

## Start the backend services for VersionEye

This project contains a [docker-compose.yml](docker-compose.yml) file which describes the backend services
of VersionEye. You can start the backend services like this:

```
docker-compose up -d
```

That will start:

 - MongoDB
 - RabbitMQ
 - ElasticSearch
 - Memcached

For persistence you should comment in and adjust the mount volumes in [docker-compose.yml](docker-compose.yml)
for MongoDB and ElasticSearch. If you are not interested in persisting the data on your host you can
let it untouched.

Shutting down the backend services works like this:

```
docker-compose down
```

## Configuration

All important configuration values are read from environment variable. Before you start
VersioneyeCore.new you should adjust the values in [scripts/set_vars_for_dev.sh](scripts/set_vars_for_dev.sh)
and load them like this:

```
source ./scripts/set_vars_for_dev.sh
```

The most important env. variables are the ones for the backend services, which point to MongoDB, ElasticSearch,
RabbitMQ and Memcached.

## Install dependencies

If the backend services are all up and running and the environment variables are set correctly
you can install the dependencies with `bundler`. If `bundler` is not installed on your machine
run this command to install it:

```
gem install bundler
```

Then you can install the dependencies like this:

```
bundle install
```

## Ruby console

If the dependencies are installed correctly you can start the Ruby console like this:

```
rake console
```

And initiate VersionEye Core like this:

```
VersioneyeCore.new
```

Now you can play with the models and services!

## Tests

The tests for this project are running after each `git push` on [CircleCI](https://circleci.com/gh/versioneye/versioneye-core)!
First of all a Docker image is build for this project and the tests are executed inside of a Docker container.
For more details take a look to the [Dockerfile](Dockerfile) and the [circle.yml](circle.yml) file in the root directory!

If the Docker containers for the backend services are running locally, the tests can be executed locally
with this command:

```
./scripts/runtests_local.sh
```

Make sure that you followed the steps in the configuration section, before you run the tests!

All Files (80.19% covered at 106.51 hits/line)

## Support

For commercial support send a message to `support@versioneye.com`.

## License

VersionEye-Core is licensed under the MIT license!

Copyright (c) 2016 VersionEye GmbH

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Femilva%2Fversioneye-core.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Femilva%2Fversioneye-core?ref=badge_large)