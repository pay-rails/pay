require "test_helper"

class Pay::Charge::Test < ActiveSupport::TestCase
  test "belongs to a Pay::Customer" do
    assert_equal Pay::Stripe::Customer, pay_charges(:stripe).customer.class
  end

  test "braintree scope" do
    assert Pay::Charge.braintree.is_a?(ActiveRecord::Relation)
  end

  test "stripe scope" do
    assert Pay::Charge.stripe.is_a?(ActiveRecord::Relation)
  end

  test "paddle_classic scope" do
    assert Pay::Charge.paddle_classic.is_a?(ActiveRecord::Relation)
  end

  test "fake processor scope" do
    assert Pay::Charge.fake_processor.is_a?(ActiveRecord::Relation)
  end

  test "charge belongs to subscription" do
    assert_equal pay_subscriptions(:stripe), pay_charges(:stripe).subscription
  end

  test "validates charge uniqueness by Pay::Customer and processor ID" do
    user = users(:stripe)
    user.payment_processor.charges.create!(amount: 1, processor_id: "1")
    assert_raises ActiveRecord::RecordInvalid do
      user.payment_processor.charges.create!(amount: 1, processor_id: "1")
    end
  end

  test "#charged_to card" do
    assert_equal "Visa (**** **** **** 4242)", pay_charges(:stripe).charged_to
  end

  test "#charged_to paypal" do
    assert_equal "PayPal (test@example.org)", pay_charges(:braintree).charged_to
  end

  test "stores data about the charge" do
    charge = pay_charges(:stripe)
    data = {"foo" => "bar"}
    charge.update(data: data)
    assert_equal data, charge.data
  end

  test "stores metadata" do
    charge = pay_charges(:stripe)
    metadata = {"foo" => "bar"}
    charge.update(metadata: metadata)
    assert_equal metadata, charge.metadata
  end

  test "with_active_customer scope" do
    charge = pay_charges(:stripe)
    customer = charge.customer

    refute_includes Pay::Charge.with_deleted_customer, charge
    customer.update(deleted_at: Time.now)
    assert_includes Pay::Charge.with_deleted_customer, charge
  end

  test "with_deleted_customer scope" do
    charge = pay_charges(:stripe)
    customer = charge.customer

    refute_includes Pay::Charge.with_deleted_customer, charge
    customer.update(deleted_at: Time.now)

    assert_includes Pay::Charge.with_deleted_customer, charge
  end

  test "refunded" do
    assert Pay::Charge.new(amount: 1_00, amount_refunded: 1_00).refunded?
    refute Pay::Charge.new(amount: 1_00, amount_refunded: 0).refunded?
    refute Pay::Charge.new(amount: 1_00, amount_refunded: nil).refunded?
  end

  test "full_refund" do
    assert Pay::Charge.new(amount: 1_00, amount_refunded: 1_00).full_refund?
    refute Pay::Charge.new(amount: 1_00, amount_refunded: 50).full_refund?
    refute Pay::Charge.new(amount: 1_00, amount_refunded: 0).full_refund?
    refute Pay::Charge.new(amount: 1_00, amount_refunded: nil).full_refund?
  end

  test "partial_refund" do
    assert Pay::Charge.new(amount: 1_00, amount_refunded: 50).partial_refund?
    refute Pay::Charge.new(amount: 1_00, amount_refunded: 1_00).partial_refund?
    refute Pay::Charge.new(amount: 1_00, amount_refunded: 0).partial_refund?
    refute Pay::Charge.new(amount: 1_00, amount_refunded: nil).partial_refund?
  end

  test "amount_with_currency" do
    assert_equal "$0.00", Pay::Charge.new(amount: nil, currency: nil).amount_with_currency
    assert_equal "$123.45", Pay::Charge.new(amount: 123_45, currency: :usd).amount_with_currency
    assert_equal "€123,45", Pay::Charge.new(amount: 123_45, currency: :eur).amount_with_currency
    assert_equal "£123.45", Pay::Charge.new(amount: 123_45, currency: :gbp).amount_with_currency
    assert_equal "¥12,345", Pay::Charge.new(amount: 123_45, currency: :jpy).amount_with_currency
    assert_equal "12.345 ع.د", Pay::Charge.new(amount: 123_45, currency: :iqd).amount_with_currency
    assert_equal "12 345 Ft", Pay::Charge.new(amount: 123_45, currency: :huf).amount_with_currency
  end

  test "amount_refunded_with_currency" do
    assert_equal "$0.00", Pay::Charge.new(amount_refunded: nil, currency: nil).amount_with_currency
    assert_equal "$123.45", Pay::Charge.new(amount_refunded: 123_45, currency: :usd).amount_refunded_with_currency
    assert_equal "€123,45", Pay::Charge.new(amount_refunded: 123_45, currency: :eur).amount_refunded_with_currency
    assert_equal "£123.45", Pay::Charge.new(amount_refunded: 123_45, currency: :gbp).amount_refunded_with_currency
    assert_equal "¥12,345", Pay::Charge.new(amount_refunded: 123_45, currency: :jpy).amount_refunded_with_currency
    assert_equal "12.345 ع.د", Pay::Charge.new(amount_refunded: 123_45, currency: :iqd).amount_refunded_with_currency
    assert_equal "12 345 Ft", Pay::Charge.new(amount_refunded: 123_45, currency: :huf).amount_refunded_with_currency
  end

  test "line items returns an array if empty" do
    assert_equal [], pay_charges(:stripe).line_items
  end

  test "stores line items" do
    charge = pay_charges(:stripe)
    line_items = [
      {id: "li_1", description: "Item 1", quantity: 1, amount: 100}.stringify_keys,
      {id: "li_2", description: "Item 2", quantity: 2, amount: 200}.stringify_keys
    ]
    charge.update!(line_items: line_items)

    assert_equal line_items, charge.reload.line_items
  end

  test "renders receipts" do
    charge = pay_charges(:stripe)
    line_items = [
      {id: "li_1", description: "Item 1", quantity: 1, amount: 100}.stringify_keys,
      {id: "li_2", description: "Item 2", quantity: 2, amount: 200}.stringify_keys
    ]
    charge.update!(line_items: line_items, tax: 4_37)
    assert charge.receipt
  end

  test "renders invoices" do
    charge = pay_charges(:stripe)
    line_items = [
      {id: "li_1", description: "Item 1", quantity: 1, amount: 100}.stringify_keys,
      {id: "li_2", description: "Item 2", quantity: 2, amount: 200}.stringify_keys
    ]
    charge.update!(line_items: line_items, tax: 4_37)
    assert charge.invoice
  end
end
