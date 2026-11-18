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
    # A callable that takes no arguments isn't passed the customer
    Pay::Stripe.client_options = -> { {api_key: "sk_test_other_platform"} }

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

  test "client_options can't set the Connect account" do
    Pay::Stripe.client_options = -> { {stripe_account: "acct_default"} }

    error = assert_raises(ArgumentError) { pay_merchants(:stripe).transfer(amount: 1_00) }
    assert_match "can't set stripe_account", error.message
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

    assert_first_request_uses_api_key "sk_test_customer_#{pay_subscription.customer.id}", "subscriptions/sub_1" do
      pay_subscription.sync!
    end
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

  test "charge webhooks pass the payload's customer to client_options for the first request" do
    use_api_key_per_customer

    assert_first_request_uses_api_key "sk_test_customer_#{pay_customers(:stripe).id}", "charges/ch_1234" do
      Pay::Stripe::Webhooks::ChargeUpdated.new.call(stripe_event("charge.updated"))
    end
  end

  test "subscription webhooks pass the payload's customer to client_options for the first request" do
    use_api_key_per_customer
    event = stripe_event("subscription.updated", overrides: {"object" => {"customer" => "cus_1234"}})

    assert_first_request_uses_api_key "sk_test_customer_#{pay_customers(:stripe).id}", "subscriptions/sub_00000000000000" do
      Pay::Stripe::Webhooks::SubscriptionUpdated.new.call(event)
    end
  end

  test "payment method webhooks pass the payload's customer to client_options for the first request" do
    use_api_key_per_customer

    assert_first_request_uses_api_key "sk_test_customer_#{pay_customers(:stripe).id}", "payment_methods/card_1JN6Z1KXBGcbgpbZ2AZJOYEZ" do
      Pay::Stripe::Webhooks::PaymentMethodAttached.new.call(stripe_event("payment_method.attached"))
    end
  end

  test "payment intent webhooks pass the payload's customer to client_options for every request" do
    use_api_key_per_customer
    headers = {"Authorization" => "Bearer sk_test_customer_#{pay_customers(:stripe).id}"}
    event = ::Stripe::Event.construct_from(data: {object: {id: "pi_1", object: "payment_intent", customer: "cus_1234"}})

    payment_intent = stub_request(:get, "https://api.stripe.com/v1/payment_intents/pi_1")
      .with(headers: headers)
      .to_return(body: {id: "pi_1", object: "payment_intent", latest_charge: "ch_1"}.to_json)
    charge = stub_request(:get, %r{\Ahttps://api.stripe.com/v1/charges/ch_1})
      .with(headers: headers)
      .to_return(status: 404, body: {error: {message: "No such charge"}}.to_json)

    assert_raises(Pay::Stripe::Error) { Pay::Stripe::Webhooks::PaymentIntentSucceeded.new.call(event) }
    assert_requested payment_intent
    assert_requested charge
  end

  test "checkout session webhooks pass the customer they just created to client_options" do
    use_api_key_per_customer
    event = stripe_event("checkout.session.completed", overrides: {"object" => {"client_reference_id" => Pay::Stripe.to_client_reference_id(users(:none))}})
    subscription_url = %r{\Ahttps://api.stripe.com/v1/subscriptions/sub_1LNkeSKXBGcbgpbZ7jMqOPSi}

    stub_request(:get, subscription_url)
      .to_return(status: 404, body: {error: {message: "No such subscription"}}.to_json)

    assert_raises(Pay::Stripe::Error) { Pay::Stripe::Webhooks::CheckoutSessionCompleted.new.call(event) }

    # The webhook creates this Pay::Customer, so its key is only known afterwards
    pay_customer = users(:none).pay_customers.find_by!(processor_id: event.data.object.customer)
    assert_requested :get, subscription_url, headers: {"Authorization" => "Bearer sk_test_customer_#{pay_customer.id}"}
  end

  test "webhooks for a customer Pay doesn't have use the global Stripe API key" do
    use_api_key_per_customer
    event = stripe_event("charge.succeeded")
    assert_nil Pay::Stripe.find_pay_customer(event.data.object.customer)

    assert_first_request_uses_api_key ::Stripe.api_key, "charges/ch_chargeid" do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(event)
    end
  end

  test "invoices rebuilt for receipts page through lines with the customer's API key and Connect account" do
    use_api_key_per_customer
    charge = pay_charges(:stripe)
    charge.update!(stripe_account: "acct_123", data: charge.data.merge("stripe_invoice" => paged_list_owner("in_1", "invoice", :lines, "il")))

    stub_next_pages("/v1/invoices/in_1/lines", "il", headers: {"Authorization" => "Bearer sk_test_customer_#{charge.customer.id}", "Stripe-Account" => "acct_123"})

    assert_equal %w[il_1 il_2 il_3], charge.stripe_invoice.lines.auto_paging_each.map(&:id)
  end

  test "subscriptions rebuilt from the database page through items with the customer's API key and Connect account" do
    use_api_key_per_customer
    pay_subscription = pay_subscriptions(:stripe)
    pay_subscription.update!(stripe_account: "acct_123", object: paged_list_owner("sub_1", "subscription", :items, "si"))

    stub_next_pages("/v1/subscription_items", "si", headers: {"Authorization" => "Bearer sk_test_customer_#{pay_subscription.customer.id}", "Stripe-Account" => "acct_123"})

    assert_equal %w[si_1 si_2 si_3], pay_subscription.stripe_object.items.auto_paging_each.map(&:id)
  end

  test "webhook events page through lists on the Connect account that sent them" do
    event = {id: "evt_1", object: "event", account: "acct_123", type: "invoice.paid", data: {object: paged_list_owner("in_1", "invoice", :lines, "il")}}
    pay_webhook = Pay::Webhook.new(processor: :stripe, event_type: "invoice.paid", event: event.deep_stringify_keys)

    stub_next_pages("/v1/invoices/in_1/lines", "il", headers: {"Stripe-Account" => "acct_123"})

    assert_equal %w[il_1 il_2 il_3], pay_webhook.rehydrated_event.data.object.lines.auto_paging_each.map(&:id)
  end

  private

  # A Stripe object with an embedded list that has more pages to fetch
  def paged_list_owner(id, object, list, prefix)
    url = (list == :items) ? "/v1/subscription_items" : "/v1/#{object}s/#{id}/#{list}"
    {"id" => id, "object" => object, list.to_s => {"object" => "list", "url" => url, "has_more" => true, "data" => [{"id" => "#{prefix}_1"}]}}
  end

  # Stubs pages 2 and 3, so the test checks the options carry over more than one page
  def stub_next_pages(path, prefix, headers:)
    [2, 3].each do |page|
      stub_request(:get, "https://api.stripe.com#{path}")
        .with(query: hash_including("starting_after" => "#{prefix}_#{page - 1}"), headers: headers)
        .to_return(body: {object: "list", url: path, has_more: page < 3, data: [{id: "#{prefix}_#{page}"}]}.to_json)
    end
  end

  def use_api_key_per_customer
    Pay::Stripe.client_options = ->(customer: nil, **) { {api_key: "sk_test_customer_#{customer.id}"} if customer }
  end

  # A request sent with another API key doesn't match the stub, so WebMock fails the test
  def assert_first_request_uses_api_key(api_key, path)
    request = stub_request(:get, %r{\Ahttps://api.stripe.com/v1/#{path}})
      .with(headers: {"Authorization" => "Bearer #{api_key}"})
      .to_return(status: 404, body: {error: {message: "Not found"}}.to_json)

    assert_raises(Pay::Stripe::Error) { yield }
    assert_requested request
  end
end
