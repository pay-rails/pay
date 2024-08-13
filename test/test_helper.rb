# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Disable warnings locally
$VERBOSE = ENV["CI"]

# Configure all the payment providers for testing
ENV["STRIPE_PRIVATE_KEY"] ||= "sk_test_fake"
ENV["STRIPE_SIGNING_SECRET"] ||= "whsec_x"

# Paddle Classic configuration
require "openssl"
require "base64"
paddle_public_key = OpenSSL::PKey::RSA.new(File.read("test/fixtures/files/paddle_classic/verification/paddle_public_key.pem"))
ENV["PADDLE_CLASSIC_PUBLIC_KEY_BASE64"] = Base64.encode64(paddle_public_key.to_der)
ENV["PADDLE_CLASSIC_ENVIRONMENT"] ||= "sandbox"
ENV["PADDLE_CLASSIC_VENDOR_ID"] ||= "1"
ENV["PADDLE_CLASSIC_VENDOR_AUTH_CODE"] ||= "x"

ENV["PADDLE_BILLING_ENVIRONMENT"] ||= "sandbox"
ENV["PADDLE_BILLING_SELLER_ID"] ||= "111"
ENV["PADDLE_BILLING_API_KEY"] ||= "secret"

require "braintree"
require "stripe"
require "paddle"
require "receipts"

require File.expand_path("dummy/config/environment.rb", __dir__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("dummy/db/migrate", __dir__), File.expand_path("../db/migrate", __dir__)]
require "rails/test_help"
require "minitest/mock"
require "mocha/minitest"

require_relative "support/braintree"
require_relative "support/stripe"
require_relative "support/vcr"

# Uncomment to view the stacktrace for debugging tests
Rails.backtrace_cleaner.remove_silencers!

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths << File.expand_path("../fixtures", __FILE__)
  ActionDispatch::IntegrationTest.fixture_paths << File.expand_path("../fixtures", __FILE__)
elsif ActiveSupport::TestCase.respond_to?(:fixture_path=)
  ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
end
ActiveSupport::TestCase.file_fixture_path = File.expand_path("../fixtures/files", __FILE__)
ActiveSupport::TestCase.fixtures :all

class ActiveSupport::TestCase
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  def json_fixture(name)
    JSON.parse File.read(file_fixture(name + ".json"))
  end

  def braintree_event(name)
    raw = json_fixture("braintree/#{name}")
    Pay.braintree_gateway.webhook_notification.parse(raw["bt_signature"], raw["bt_payload"])
  end

  def paddle_billing_event(name)
    OpenStruct.new json_fixture("paddle_billing/#{name}")
  end

  def paddle_classic_event(name, overrides: {})
    OpenStruct.new json_fixture("paddle_classic/#{name}").deep_merge(overrides)
  end

  def stripe_event(name, overrides: {})
    data = json_fixture("stripe/#{name}")
    ::Stripe::Event.construct_from({data: data.deep_merge(overrides)})
  end

  def travel_to_cassette
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
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
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
