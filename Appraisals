appraise "rails-7.0" do
  gem "rails", "~> 7.0.0"
  gem "sqlite3", "~> 1.4"

  # Ruby 3.4+
  gem "benchmark"
  gem "drb"
  gem "mutex_m"

  # Fixes uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger (NameError)
  gem "concurrent-ruby", "< 1.3.5"
end

appraise "rails-7.1" do
  gem "rails", "~> 7.1.0"
  gem "sqlite3", "~> 1.4"
end

appraise "rails-7.2" do
  gem "rails", "~> 7.2.0.rc1"
end

appraise "rails-8.0" do
  gem "rails", "~> 8.0.0"
end

appraise "rails-8.1" do
  gem "rails", "~> 8.1.0"
end

appraise "rails-main" do
  gem "rails", github: "rails/rails", branch: "main"
end
