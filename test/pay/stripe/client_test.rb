require "test_helper"

# These tests check the HTTP requests stripe-ruby actually sends, so they use WebMock stubs instead of a VCR cassette.
# With no cassette inserted, a request that doesn't match a stub fails the test (WebMock raises, or Stripe rejects the fake key).
class Pay::Stripe::ClientTest < ActiveSupport::TestCase
  setup do
    VCR.eject_cassette
  end

  teardown do
    Pay::Stripe.client_options = nil
  end

  test "client uses the global Stripe API key and context by default" do
    ::Stripe.config.stubs(:stripe_context).returns("ctx_123")

    stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_1")
      .with(headers: {"Authorization" => "Bearer #{::Stripe.api_key}", "Stripe-Context" => "ctx_123"})
      .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)

    assert_equal "pi_1", Pay::Payment.from_id("pi_1").id
  end

  test "client uses the global Stripe API base and version by default" do
    ::Stripe.config.stubs(:api_base).returns("https://stripe-mock.test")
    ::Stripe.config.stubs(:api_version).returns("2020-01-01")

    stub_request(:get, "https://stripe-mock.test/v1/payment_intents/pi_1")
      .with(headers: {"Stripe-Version" => "2020-01-01"})
      .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)

    assert_equal "pi_1", Pay::Payment.from_id("pi_1").id
  end

  test "client_options override the global configuration, and objects keep using that API key" do
    Pay::Stripe.client_options = ->(**) { {api_key: "sk_test_other_platform"} }

    create = stub_request(:post, "https://api.stripe.com/v1/invoices")
      .with(headers: {"Authorization" => "Bearer sk_test_other_platform"})
      .to_return(body: {id: "in_1", object: "invoice", status: "draft"}.to_json)
    # Invoice#pay is called on the returned object rather than through the client
    pay = stub_request(:post, "https://api.stripe.com/v1/invoices/in_1/pay")
      .with(headers: {"Authorization" => "Bearer sk_test_other_platform"})
      .to_return(body: {id: "in_1", object: "invoice", status: "paid"}.to_json)

    assert_equal "paid", pay_customers(:stripe).invoice!.status
    assert_requested create
    assert_requested pay
  end

  test "connected account requests send the Stripe-Account header" do
    stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_1")
      .with(headers: {"Stripe-Account" => "acct_123"})
      .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)

    assert_equal "acct_123", Pay::Payment.from_id("pi_1", stripe_account: "acct_123").stripe_account
  end

  test "objects keep the connected account for later calls" do
    pay_customer = pay_customers(:stripe)
    pay_customer.update!(stripe_account: "acct_123")

    create = stub_request(:post, "https://api.stripe.com/v1/invoices")
      .with(headers: {"Stripe-Account" => "acct_123"})
      .to_return(body: {id: "in_1", object: "invoice", status: "draft"}.to_json)
    pay = stub_request(:post, "https://api.stripe.com/v1/invoices/in_1/pay")
      .with(headers: {"Stripe-Account" => "acct_123"})
      .to_return(body: {id: "in_1", object: "invoice", status: "paid"}.to_json)

    assert_equal "paid", pay_customer.invoice!.status
    assert_requested create
    assert_requested pay
  end

  test "the record's connected account takes precedence over client_options" do
    Pay::Stripe.client_options = ->(**) { {stripe_account: "acct_default"} }

    stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_1")
      .with(headers: {"Stripe-Account" => "acct_123"})
      .to_return(body: {id: "pi_1", object: "payment_intent", status: "succeeded"}.to_json)
    stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_2")
      .with(headers: {"Stripe-Account" => "acct_default"})
      .to_return(body: {id: "pi_2", object: "payment_intent", status: "succeeded"}.to_json)

    assert_equal "pi_1", Pay::Payment.from_id("pi_1", stripe_account: "acct_123").id
    assert_equal "pi_2", Pay::Payment.from_id("pi_2").id
  end

  test "client_options receives the customer, so background jobs use that customer's API key" do
    use_api_key_per_customer

    update = stub_request(:post, "https://api.stripe.com/v1/customers/cus_1234")
      .with(headers: {"Authorization" => "Bearer sk_test_customer_#{pay_customers(:stripe).id}"})
      .to_return(body: {id: "cus_1234", object: "customer"}.to_json)

    Pay::CustomerSyncJob.perform_now(pay_customers(:stripe).id)
    assert_requested update
  end

  test "sync! passes the record's customer to client_options for the first request" do
    use_api_key_per_customer
    pay_subscription = pay_subscriptions(:stripe)

    retrieve = stub_request(:get, %r{\Ahttps://api.stripe.com/v1/subscriptions/sub_1})
      .with(headers: {"Authorization" => "Bearer sk_test_customer_#{pay_subscription.customer.id}"})
      .to_return(status: 404, body: {error: {message: "No such subscription"}}.to_json)

    assert_raises(Pay::Stripe::Error) { pay_subscription.sync! }
    assert_requested retrieve
  end

  test "syncs use the customer for requests after looking it up" do
    use_api_key_per_customer

    invoice_payments = stub_request(:get, %r{\Ahttps://api.stripe.com/v1/invoice_payments})
      .with(headers: {"Authorization" => "Bearer sk_test_customer_#{pay_customers(:stripe).id}"})
      .to_return(body: {object: "list", data: [], has_more: false}.to_json)

    # The charge's customer (cus_1234) is only known once the charge has been fetched
    Pay::Stripe::Charge.sync("ch_123", object: fake_stripe_charge)
    assert_requested invoice_payments
  end

  test "syncs that start from an ID pass no customer for the first request" do
    customers = []
    Pay::Stripe.client_options = ->(customer: nil, **) {
      customers << customer
      nil
    }

    stub_request(:get, %r{\Ahttps://api.stripe.com/v1/charges/ch_123})
      .to_return(status: 404, body: {error: {message: "No such charge"}}.to_json)

    assert_raises(Pay::Stripe::Error) { Pay::Stripe::Charge.sync("ch_123") }
    assert_equal [nil], customers
  end

  private

  def use_api_key_per_customer
    Pay::Stripe.client_options = ->(customer: nil, **) { {api_key: "sk_test_customer_#{customer.id}"} if customer }
  end
end
