# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Configure all the payment providers for testing
# VCR replaces every occurrence of these values in cassettes, so fake credentials must be distinctive strings
ENV["STRIPE_PRIVATE_KEY"] ||= "sk_test_fake"
ENV["STRIPE_SIGNING_SECRET"] ||= "whsec_x"

# Paddle Classic configuration
require "openssl"
require "base64"
paddle_public_key = OpenSSL::PKey::RSA.new(File.read(File.expand_path("fixtures/files/paddle_classic/verification/paddle_public_key.pem", __dir__)))
ENV["PADDLE_CLASSIC_PUBLIC_KEY_BASE64"] = Base64.encode64(paddle_public_key.to_der)
ENV["PADDLE_CLASSIC_ENVIRONMENT"] ||= "sandbox"
ENV["PADDLE_CLASSIC_VENDOR_ID"] ||= "paddle_classic_vendor_id"
ENV["PADDLE_CLASSIC_VENDOR_AUTH_CODE"] ||= "paddle_classic_vendor_auth_code"

ENV["PADDLE_BILLING_ENVIRONMENT"] ||= "sandbox"
ENV["PADDLE_BILLING_SELLER_ID"] ||= "111"
ENV["PADDLE_BILLING_API_KEY"] ||= "paddle_billing_api_key"

require "braintree"
require "stripe"
require "paddle"
require "receipts"

require File.expand_path("dummy/config/environment.rb", __dir__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("dummy/db/migrate", __dir__), File.expand_path("../db/migrate", __dir__)]
require "rails/test_help"
require "mocha/minitest"

require_relative "support/braintree"
require_relative "support/engine_integration_test"
require_relative "support/stripe"
require_relative "support/vcr"
require_relative "support/payment_method_tests"

# Show the full stacktrace for debugging tests
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

  def lemon_squeezy_event(name, overrides: {})
    Pay::Webhook.new(processor: :lemon_squeezy, event: json_fixture("lemon_squeezy/#{name}").deep_merge(overrides)).rehydrated_event
  end

  def paddle_billing_event(name, overrides: {})
    Pay::Webhook.new(processor: :paddle_billing, event: json_fixture("paddle_billing/#{name}").deep_merge(overrides)).rehydrated_event
  end

  def paddle_classic_event(name, overrides: {})
    ActiveSupport::InheritableOptions.new json_fixture("paddle_classic/#{name}").deep_merge(overrides).deep_symbolize_keys
  end

  def stripe_event(name, overrides: {}, account: nil)
    data = json_fixture("stripe/#{name}")
    ::Stripe::Event.construct_from({data: data.deep_merge(overrides), account: account}.compact)
  end

  def travel_to_cassette
    travel_to(VCR.current_cassette&.originally_recorded_at || Time.current) do
      yield
    end
  end

  # Sets environment variables for the block and restores the original environment afterwards.
  # A nil value removes the variable.
  def with_env(values)
    original_env = ENV.to_hash
    ENV.update(values)
    yield
  ensure
    ENV.replace(original_env)
  end

  # Runs the block in a Ractor and returns its result. Skips on Rubies without Ractor#value (before 4.0).
  #
  # The Ractor runs in a forked child process. Creating a Ractor switches the Ruby process into multi-Ractor
  # mode for the rest of its life, and Ruby 4.0 still segfaults now and then in that mode, so the process that
  # runs the rest of the suite must never create one. The result (or the error) is marshalled back over a pipe.
  def in_ractor(&block)
    skip "Ractor#value requires Ruby 4.0+" unless defined?(Ractor) && Ractor.method_defined?(:value)
    skip "in_ractor requires fork" unless Process.respond_to?(:fork)

    reader, writer = IO.pipe
    pid = fork do
      reader.close
      Warning[:experimental] = false # Ruby warns on every Ractor.new that the API is experimental
      result = begin
        {value: Ractor.new(&block).value}
      rescue Exception => e # rubocop:disable Lint/RescueException -- report Ractor::IsolationError and friends as a test failure
        cause = e.cause ? " (cause: #{e.cause.class}: #{e.cause.message})" : ""
        {error: "#{e.class}: #{e.message}#{cause}"}
      end
      writer.write Marshal.dump(result)
      writer.close
      exit!(0)
    end

    writer.close
    output = reader.read
    Process.wait(pid)
    flunk "Ractor child exited without a result" if output.empty?

    result = Marshal.load(output)
    flunk result[:error] if result.key?(:error)
    result[:value]
  ensure
    reader&.close
  end
end
