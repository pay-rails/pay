require "test_helper"

class Pay::Charge::Test < ActiveSupport::TestCase
  test "belongs to a Pay::Customer" do
    assert_equal Pay::Customer, pay_charges(:stripe).customer.class
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
    charges = Pay::Charge.with_deleted_customer

    refute_includes charges, charge
    customer.update(deleted_at: Time.now)

    assert_includes charges, charge
  end

  private
end
