require "test_helper"

class Pay::Lago::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lago)
  end

  test "lago processor customer" do
    assert_equal @pay_customer, @pay_customer.customer
  end

  test "lago processor charge" do
    skip
    assert_difference "Pay::Charge.count" do
      @pay_customer.charge(10_00)
    end
  end

  test "lago processor subscribe" do
    skip
    assert_difference "Pay::Subscription.count" do
      @pay_customer.subscribe
    end
  end

  test "lago processor subscribe with promotion code" do
    skip
    assert_difference "Pay::Subscription.count" do
      @pay_customer.subscribe(promotion_code: "promo_xxx123")
    end
  end

  test "lago processor add payment method" do
    skip
    assert_difference "Pay::PaymentMethod.count" do
      @pay_customer.add_payment_method("x", default: true)
    end

    payment_method = @pay_customer.default_payment_method
    assert_equal "card", payment_method.type
    assert_equal "lago", payment_method.brand
  end

  test "generates lago processor_id" do
    skip
    user = users(:none)
    pay_customer = user.set_payment_processor :lago, allow_lago: true
    assert_nil pay_customer.processor_id
    pay_customer.customer
    assert_not_nil pay_customer.processor_id
  end

  test "generic trial" do
    skip
    user = users(:none)
    pay_customer = user.set_payment_processor :lago, allow_lago: true

    refute pay_customer.on_generic_trial?

    time = 14.days.from_now
    pay_customer.subscribe(trial_ends_at: time, ends_at: time)

    assert pay_customer.on_generic_trial?
  end
end
