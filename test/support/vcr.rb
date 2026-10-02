require "webmock/minitest"

VCR.configure do |c|
  c.cassette_library_dir = "test/vcr_cassettes"
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
  c.filter_sensitive_data("<VENDOR_ID>") { ENV["PADDLE_CLASSIC_VENDOR_ID"] }
  c.filter_sensitive_data("<VENDOR_AUTH_CODE>") { ENV["PADDLE_CLASSIC_VENDOR_AUTH_CODE"] }
  c.filter_sensitive_data("<STRIPE_PRIVATE_KEY>") { Pay::Stripe.private_key }
  c.filter_sensitive_data("<BRAINTREE_PRIVATE_KEY>") { Pay::Braintree.private_key }
  c.filter_sensitive_data("<PADDLE_API_KEY>") { Pay::PaddleBilling.api_key }
  c.filter_sensitive_data("<LEMON_SQUEEZY_API_KEY>") { Pay::LemonSqueezy.api_key }
end

class ActiveSupport::TestCase
  setup do
    # Recorded requests a test no longer makes fail the test, so stale cassettes get noticed
    VCR.insert_cassette vcr_cassette_name, allow_unused_http_interactions: false
  end

  teardown do
    cassette = VCR.current_cassette
    VCR.eject_cassette
  rescue VCR::Errors::UnusedHTTPInteractionError
    puts
    puts "Unused HTTP requests in cassette: #{cassette.file}"
    raise
  end

  private

  # Cassettes are stored per test class, like test/vcr_cassettes/pay/stripe/customer_test/stripe_can_create_a_charge.yml
  def vcr_cassette_name
    "#{self.class.name.underscore}/#{name.delete_prefix("test_")}"
  end
end

if ENV["SKIP_VCR"]
  VCR.turn_off!(ignore_cassettes: true)
  WebMock.allow_net_connect!
end
