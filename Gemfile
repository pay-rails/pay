source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Declare your gem's dependencies in pay.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

gem "byebug"
gem "appraisal", github: "thoughtbot/appraisal"
gem "overcommit"
gem "standard"
gem "mocha"
gem "vcr"
gem "webmock"

gem "braintree", ">= 2.92.0"
gem "stripe", "~> 12.0"
gem "paddle", "~> 2.2"
gem "lemonsqueezy", "~> 1.0"

gem "receipts"
gem "prawn"

# Test against different databases
gem "pg"
gem "mysql2"
gem "sqlite3", "~> 1.7"

# Used for the dummy Rails app integration
gem "puma"
gem "web-console", group: :development

gem "sprockets-rails"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

# Ruby 3.1+ drops these built-in gems
gem "net-imap", require: false
gem "net-pop", require: false
gem "net-smtp", require: false
