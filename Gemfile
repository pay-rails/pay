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
gem "appraisal", github: "excid3/appraisal", branch: "fix-bundle-env"

gem "braintree", ">= 2.92.0", "< 4.0"
gem "stripe", ">= 2.8"
gem "paddle_pay", "~> 0.0.1"

# Test against different databases
gem "sqlite3", "~> 1.4"
gem "mysql2"
gem "pg"

# Used for the dummy Rails app integration
gem "puma"
gem "standard"
gem "turbolinks"
gem "web-console", group: :development
gem "webpacker"
