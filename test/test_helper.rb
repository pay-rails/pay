# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Disable warnings locally
$VERBOSE = ENV["CI"]

require File.expand_path("dummy/config/environment.rb", __dir__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("dummy/db/migrate", __dir__), File.expand_path("../db/migrate", __dir__)]
require "rails/test_help"
require "byebug"

# Processors for testing
require "braintree"
require "stripe"
require "paddle_pay"

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

class ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  def fake_event(name, format: :json)
    JSON.parse File.read("test/support/fixtures/#{name}.#{format}")
  end

  def braintree_event(name, format: :json)
    raw = fake_event name, format: format
    Pay.braintree_gateway.webhook_notification.parse(raw["bt_signature"], raw["bt_payload"])
  end

  def stripe_event(filename, overrides: {})
    data = JSON.parse(File.read(filename))
    ::Stripe::Event.construct_from({data: data.deep_merge(overrides)})
  end

  def travel_to_cassette
    travel_to(VCR.current_cassette.originally_recorded_at || Time.current) do
      yield
    end
  end

  def assert_indexed_selects
    subscriber = ActiveSupport::Notifications.subscribe "sql.active_record" do |name, started, finished, unique_id, data|
      if data[:sql].starts_with? "SELECT"
        result = data[:connection].explain(data[:sql], data[:binds]).downcase
        assert result.include?("index"), "Query `#{data[:name]}` did not use an index!"
      end
    end

    yield

    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end

require "minitest/mock"
require "mocha/minitest"
require "vcr"

# Uncomment to view the stacktrace for debugging tests
Rails.backtrace_cleaner.remove_silencers!

# Configure all the payment providers for testing
ENV["STRIPE_PRIVATE_KEY"] ||= "sk_test_fake"

require "pay/stripe"
require "pay/braintree"
require "pay/paddle"
Pay::Stripe.setup
Pay::Braintree.setup
Pay::Paddle.setup

# Braintree configuration
Pay.braintree_gateway = Braintree::Gateway.new(
  environment: :sandbox,
  merchant_id: "zyfwpztymjqdcc5g",
  public_key: "5r59rrxhn89npc9n",
  private_key: "00f0df79303e1270881e5feda7788927"
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

# Paddle configuration
paddle_public_key = OpenSSL::PKey::RSA.new(File.read("test/support/fixtures/paddle/verification/paddle_public_key.pem"))
ENV["PADDLE_PUBLIC_KEY_BASE64"] = Base64.encode64(paddle_public_key.to_der)

unless ENV["SKIP_VCR"]
  require "webmock/minitest"

  VCR.configure do |c|
    c.cassette_library_dir = "test/vcr_cassettes"
    c.hook_into :webmock
    c.allow_http_connections_when_no_cassette = true
    c.filter_sensitive_data("<VENDOR_ID>") { ENV["PADDLE_VENDOR_ID"] }
    c.filter_sensitive_data("<VENDOR_AUTH_CODE>") { ENV["PADDLE_VENDOR_AUTH_CODE"] }
    c.filter_sensitive_data("<STRIPE_PRIVATE_KEY>") { Pay::Stripe.private_key }
    c.filter_sensitive_data("<BRAINTREE_PRIVATE_KEY>") { Pay::Braintree.private_key }
    c.filter_sensitive_data("<PADDLE_PRIVATE_KEY>") { Pay::Paddle.vendor_auth_code }
  end

  class ActiveSupport::TestCase
    setup do
      VCR.insert_cassette name
    end

    teardown do
      VCR.eject_cassette name
    end
  end
end
