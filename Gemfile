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

gem "appraisal"
gem "mocha"
gem "standard"
gem "vcr"
gem "webmock"

gem "braintree", ">= 2.92.0"
gem "lemonsqueezy", "~> 1.0"
gem "paddle", "~> 2.6"
gem "stripe", "~> 18.0"

gem "prawn"
gem "receipts"

# Test against different databases
gem "mysql2"
gem "pg"
gem "sqlite3"

# Used for the dummy Rails app integration
gem "puma"
gem "web-console", group: :development

gem "importmap-rails"
gem "sprockets-rails"
gem "stimulus-rails"
gem "turbo-rails"

gem "minitest", "< 6.0.0"
