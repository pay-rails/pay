# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
require "rails/test_help"

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'
require "support/schema"
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

require 'braintree'
Braintree::Configuration.environment = :development
Braintree::Configuration.merchant_id = "integration_merchant_id"
Braintree::Configuration.public_key = "integration_public_key"
Braintree::Configuration.private_key = "integration_private_key"

require 'minitest/mock'
require 'mocha/mini_test'

require 'stripe_mock'

# Uncomment to view the stacktrace for debugging tests
#Rails.backtrace_cleaner.remove_silencers!
