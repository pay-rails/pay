# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Disable warnings locally
$VERBOSE = ENV["CI"]

# Configure all the payment providers for testing
ENV["STRIPE_PRIVATE_KEY"] ||= "sk_test_fake"

# Paddle configuration
paddle_public_key = OpenSSL::PKey::RSA.new(File.read("test/support/fixtures/paddle/verification/paddle_public_key.pem"))
ENV["PADDLE_PUBLIC_KEY_BASE64"] = Base64.encode64(paddle_public_key.to_der)
ENV["PADDLE_ENVIRONMENT"] = "sandbox"

require "braintree"
require "stripe"
require "paddle_pay"
require "receipts"

require File.expand_path("dummy/config/environment.rb", __dir__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("dummy/db/migrate", __dir__), File.expand_path("../db/migrate", __dir__)]
require "rails/test_help"
require "byebug"
require "minitest/mock"
require "mocha/minitest"

require_relative "support/braintree"
require_relative "support/vcr"

# Uncomment to view the stacktrace for debugging tests
Rails.backtrace_cleaner.remove_silencers!

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

  def braintree_event(name)
    raw = fake_event "braintree/#{name}"
    Pay.braintree_gateway.webhook_notification.parse(raw["bt_signature"], raw["bt_payload"])
  end

  def paddle_event(name)
    OpenStruct.new fake_event("paddle/#{name}")
  end

  def stripe_event(name, overrides: {})
    data = fake_event("stripe/#{name}")
    ::Stripe::Event.construct_from({data: data.deep_merge(overrides)})
  end

  def travel_to_cassette
    travel_to(VCR.current_cassette.originally_recorded_at || Time.current) do
      yield
    end
  end

  def create_subscription(options = {})
    defaults = {
      name: "default",
      processor_id: rand(1..999_999_999),
      processor_plan: "default",
      quantity: "1",
      status: :active
    }

    @pay_customer.subscriptions.create! defaults.merge(options)
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
