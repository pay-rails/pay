appraise "rails-7.1" do
  gem "rails", "~> 7.1.0"
  gem "sqlite3", "~> 1.4"

  # Rails::LineFiltering#run passes arguments minitest 6 no longer accepts
  gem "minitest", "< 6"

  # json 3.0 removed the quirks_mode option still passed by Rails < 8.1
  gem "json", "< 3"
end

appraise "rails-7.2" do
  gem "rails", "~> 7.2.0.rc1"

  # json 3.0 removed the quirks_mode option still passed by Rails < 8.1
  gem "json", "< 3"
end

appraise "rails-8.0" do
  gem "rails", "~> 8.0.0"

  # json 3.0 removed the quirks_mode option still passed by Rails < 8.1
  gem "json", "< 3"
end

appraise "rails-8.1" do
  gem "rails", "~> 8.1.0"
end

appraise "rails-main" do
  gem "rails", github: "rails/rails", branch: "main"
end
