require "test_helper"

class Pay::FakeProcessor::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:fake)
  end

  test "doesn't allow fake processor by default" do
    assert_raises Pay::Error do
      users(:none).set_payment_processor :fake_processor
    end
  end

  test "allows fake processor if enabled" do
    assert_nothing_raised do
      users(:none).set_payment_processor :fake_processor, allow_fake: true
    end
  end

  test "fake processor customer" do
    assert_equal @pay_customer, @pay_customer.customer
  end

  test "fake processor charge" do
    assert_difference "Pay::Charge.count" do
      @pay_customer.charge(10_00)
    end
  end

  test "fake processor charge options" do
    assert_difference "Pay::Charge.count" do
      @pay_customer.charge(10_00, {description: "Hello world"})
    end
  end

  test "fake processor subscribe" do
    assert_difference "Pay::Subscription.count" do
      @pay_customer.subscribe
    end
  end

  test "fake processor subscribe with promotion code" do
    assert_difference "Pay::Subscription.count" do
      @pay_customer.subscribe(promotion_code: "promo_xxx123")
    end
  end

  test "fake processor add new default payment method" do
    old_payment_method = @pay_customer.add_payment_method("old", default: true)
    assert_equal old_payment_method.id, @pay_customer.default_payment_method.id

    new_payment_method = nil
    assert_difference "Pay::PaymentMethod.count" do
      new_payment_method = @pay_customer.add_payment_method("new", default: true)
    end

    payment_method = @pay_customer.default_payment_method
    assert_equal new_payment_method.id, payment_method.id
    assert_equal "card", payment_method.type
    assert_equal "Fake", payment_method.brand
  end

  test "generates fake processor_id" do
    user = users(:none)
    pay_customer = user.set_payment_processor :fake_processor, allow_fake: true
    assert_nil pay_customer.processor_id
    pay_customer.customer
    assert_not_nil pay_customer.processor_id
  end

  test "generic trial" do
    user = users(:none)
    pay_customer = user.set_payment_processor :fake_processor, allow_fake: true

    refute pay_customer.on_generic_trial?

    time = 14.days.from_now
    pay_customer.subscribe(trial_ends_at: time, ends_at: time)

    assert pay_customer.on_generic_trial?
  end
end
