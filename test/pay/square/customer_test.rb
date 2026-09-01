require "test_helper"

class Pay::Square::CustomerTest < Pay::Square::TestCase
  setup do
    @user = users(:none)
    @pay_customer = @user.set_payment_processor(:square, square_account: "MERCHANT_1")
    @pay_customer.update!(processor_id: "sqcust_test")
  end

  test "creates a Square customer and assigns processor_id" do
    @pay_customer.update!(processor_id: nil)
    stub_square(:post, "customers", response: {customer: {id: "sqcust_new"}})

    record = @pay_customer.api_record
    assert_equal "sqcust_new", record.id
    assert_equal "sqcust_new", @pay_customer.reload.processor_id
  end

  test "adds a card on file" do
    stub_square(:post, "cards", response: {card: square_card_json})

    pay_payment_method = @pay_customer.add_payment_method("cnon:card-nonce-ok", default: true)
    assert_equal "card_test", pay_payment_method.processor_id
    assert_equal "card", pay_payment_method.payment_method_type
    assert_equal "VISA", pay_payment_method.brand
    assert_equal "4242", pay_payment_method.last4
    assert_equal "MERCHANT_1", pay_payment_method.square_account
    assert pay_payment_method.default?
  end

  test "creates a charge with an application fee and exposes Square ids" do
    stub_square(:post, "payments", response: {payment: square_payment_json})

    charge = @pay_customer.charge(10_00, source_id: "cnon:card-nonce-ok", application_fee_amount: 1_00)

    assert_instance_of Pay::Square::Charge, charge
    assert_equal 10_00, charge.amount
    assert_equal 1_00, charge.application_fee_amount
    assert_equal "pmt_test", charge.processor_id
    assert_equal "ord_test", charge.square_order_id
    assert_equal "COMPLETED", charge.square_status
    assert_equal "MERCHANT_1", charge.square_account
  end

  test "charge reuses a caller-provided idempotency key" do
    stub_square(:post, "payments", response: {payment: square_payment_json})
      .with { |req| JSON.parse(req.body)["idempotency_key"] == "appointment-42" }

    charge = @pay_customer.charge(10_00, source_id: "cnon:x", idempotency_key: "appointment-42")
    assert_equal "pmt_test", charge.processor_id
  end

  test "charge retries once with a refreshed token on 401" do
    stub_request(:post, square_url("payments")).to_return(
      {status: 401, body: {errors: [{category: "AUTHENTICATION_ERROR", code: "UNAUTHORIZED"}]}.to_json, headers: {"Content-Type" => "application/json"}},
      {status: 200, body: {payment: square_payment_json}.to_json, headers: {"Content-Type" => "application/json"}}
    )

    charge = @pay_customer.charge(10_00, source_id: "cnon:x")

    assert_equal "pmt_test", charge.processor_id
    assert_equal 2, @square_token_calls.size
    assert_equal false, @square_token_calls[0][:force_refresh]
    assert_equal true, @square_token_calls[1][:force_refresh], "expected the retry to force-refresh the token"
  end

  test "maps Square API errors to Pay::Square::Error" do
    stub_square(:post, "payments", status: 422, response: {errors: [{category: "INVALID_REQUEST_ERROR", code: "BAD_REQUEST"}]})

    assert_raises(Pay::Square::Error) do
      @pay_customer.charge(10_00, source_id: "cnon:x")
    end
  end

  test "raises when the access token provider is not configured" do
    Pay::Square.access_token_provider = nil
    assert_raises(Pay::Square::Error) do
      @pay_customer.charge(10_00, source_id: "cnon:x")
    end
  end

  test "raises when the resolver returns a blank token" do
    Pay::Square.access_token_provider = ->(pay_customer, force_refresh = false) { "" }
    assert_raises(Pay::Square::Error) do
      @pay_customer.charge(10_00, source_id: "cnon:x")
    end
  end

  test "never persists the access token on any record" do
    stub_square(:post, "cards", response: {card: square_card_json})
    stub_square(:post, "payments", response: {payment: square_payment_json})

    pay_payment_method = @pay_customer.add_payment_method("cnon:x", default: true)
    charge = @pay_customer.charge(10_00, source_id: "cnon:x")

    [@pay_customer.reload, pay_payment_method.reload, charge.reload].each do |record|
      dump = record.attributes.to_json
      refute_includes dump, "test-token", "#{record.class} must not persist the access token"
      refute_includes dump, "fresh-token", "#{record.class} must not persist the access token"
    end
  end
end
