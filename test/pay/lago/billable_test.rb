require "test_helper"

class Pay::Lago::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lago)
    @pay_customer.processor_id = @pay_customer.pay_external_id
  end

  test "can get lago processor customer" do
    assert_equal @pay_customer.customer.external_id, @pay_customer.pay_external_id
  end

  test "can make a lago processor charge" do
    assert_difference "Pay::Charge.count" do
      @pay_customer.charge(10_00)
    end
  end

  # Subscribe to a plan with the code "default" in Lago
  test "lago processor subscribe" do
    assert_difference "Pay::Subscription.count" do
      @pay_customer.subscribe
    end
  end

  test "generates lago processor_id" do
    user = users(:none)
    pay_customer = user.set_payment_processor :lago
    assert_nil pay_customer.processor_id
    pay_customer.customer
    assert_not_nil pay_customer.processor_id
  end

  test "add payment method to lago" do
    assert_difference "Pay::PaymentMethod.count" do
      @pay_customer.add_payment_method("x", default: true)
    end

    payment_method = @pay_customer.default_payment_method
    assert_equal "card", payment_method.type
  end
end
