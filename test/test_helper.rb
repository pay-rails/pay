# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Disable warnings locally
$VERBOSE = ENV["CI"]

require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../../db/migrate", __FILE__)
require "rails/test_help"
require "minitest/rails"
require "byebug"

# Processors for testing
require "braintree"
require "stripe"
require "stripe_event"

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

require "minitest/mock"
require "mocha/minitest"

# Uncomment to view the stacktrace for debugging tests
Rails.backtrace_cleaner.remove_silencers!

require "webmock/minitest"
require "vcr"

VCR.configure do |c|
  c.cassette_library_dir = "test/vcr_cassettes"
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
end

Pay.braintree_gateway = Braintree::Gateway.new(
  environment: :sandbox,
  merchant_id: "zyfwpztymjqdcc5g",
  public_key: "5r59rrxhn89npc9n",
  private_key: "00f0df79303e1270881e5feda7788927",
)

logger = Logger.new("/dev/null")
logger.level = Logger::INFO
Pay.braintree_gateway.config.logger = logger

module Braintree
  class Configuration
    def self.gateway
      Pay.braintree_gateway
    end
  end
end

class ActiveSupport::TestCase
  setup do
    VCR.insert_cassette name
  end

  teardown do
    VCR.eject_cassette name
  end
end
