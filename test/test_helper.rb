# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
require "rails/test_help"
require "support/user"

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
  ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
  ActiveSupport::TestCase.fixtures :all
end

require 'stripe_mock'

class DbTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.establish_connection :adapter => 'sqlite3', database: ':memory:'
    {
      'users' => 'email VARCHAR(32), processor VARCHAR(32), processor_id VARCHAR(32), card_brand VARCHAR(32), card_last4 VARCHAR(32), card_exp_month INTEGER, card_exp_year INTEGER',
      'subscriptions' => 'user_id INTEGER, name VARCHAR(32), processor VARCHAR(32), processor_id VARCHAR(32), processor_plan VARCHAR(32), quantity INTEGER, trial_ends_at DATETIME, ends_at DATETIME'
    }.each do |table_name, columns_as_sql_string|
      ActiveRecord::Base.connection.execute "CREATE TABLE #{table_name} (id INTEGER NOT NULL PRIMARY KEY, #{columns_as_sql_string}, created_at DATETIME, updated_at DATETIME)"
    end

    StripeMock.start

    @billable = User.create email: "test@test.com"
    @stripe_helper = StripeMock.create_test_helper
    @stripe_helper.create_plan(id: 'test-monthly', amount: 1500)
  end

  teardown do
    StripeMock.stop
  end
end

class User < ActiveRecord::Base
  include Pay::Billable
end
