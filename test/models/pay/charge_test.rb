require "test_helper"

class Pay::Charge::Test < ActiveSupport::TestCase
  test "text data column" do
    pay_charges(:stripe).update!(stripe_account: "acct_1")
    assert_equal "acct_1", pay_charges(:stripe).stripe_account
  end

  test "belongs to a Pay::Customer" do
    assert_equal Pay::Customer, pay_charges(:stripe).customer.class
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
end
