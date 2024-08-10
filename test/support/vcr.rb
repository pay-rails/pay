require "webmock/minitest"

VCR.configure do |c|
  c.cassette_library_dir = "test/vcr_cassettes"
  c.hook_into :webmock
  c.allow_http_connections_when_no_cassette = true
  c.filter_sensitive_data("<VENDOR_ID>") { ENV["PADDLE_CLASSIC_VENDOR_ID"] }
  c.filter_sensitive_data("<VENDOR_AUTH_CODE>") { ENV["PADDLE_CLASSIC_VENDOR_AUTH_CODE"] }
  c.filter_sensitive_data("<STRIPE_PRIVATE_KEY>") { Pay::Stripe.private_key }
  c.filter_sensitive_data("<BRAINTREE_PRIVATE_KEY>") { Pay::Braintree.private_key }
  c.filter_sensitive_data("<PADDLE_PRIVATE_KEY>") { Pay::PaddleClassic.vendor_auth_code }
  c.filter_sensitive_data("<PADDLE_API_KEY>") { Pay::PaddleBilling.api_key }
  c.filter_sensitive_data("<LEMON_SQUEEZY_API_KEY>") { Pay::LemonSqueezy.api_key }
end

class ActiveSupport::TestCase
  setup do
    # Test filenames are case sensitive in CI
    VCR.insert_cassette name
  end

  teardown do
    cassette = VCR.current_cassette
    VCR.eject_cassette
  rescue VCR::Errors::UnusedHTTPInteractionError
    puts
    puts "Unused HTTP requests in cassette: #{cassette.file}"
    raise
  end
end

if ENV["SKIP_VCR"]
  VCR.turn_off!(ignore_cassettes: true)
  WebMock.allow_net_connect!
end
