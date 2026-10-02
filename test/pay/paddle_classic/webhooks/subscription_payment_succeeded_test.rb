require "test_helper"

class Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceededTest < ActiveSupport::TestCase
  setup do
    @event = paddle_classic_event("subscription_payment_succeeded")
    @pay_customer = pay_customers(:paddle_classic)
    @pay_customer.update(processor_id: @event.user_id)
  end

  test "paddle charge is created" do
    assert_difference "Pay::Charge.count" do
      Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceeded.new.call(@event)
    end

    charge = Pay::Charge.last
    assert_equal (@event.sale_gross.to_f * 100).to_i, charge.amount
    assert_equal "card", charge.payment_method_type
    assert_equal "visa", charge.brand
    assert_equal @event.receipt_url, charge.paddle_receipt_url
  end

  test "paddle charge is associated with subscription" do
    @pay_customer.subscription.update!(processor_id: @event.subscription_id)
    assert_difference "Pay::Charge.count" do
      Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceeded.new.call(@event)
    end

    assert_equal @pay_customer.subscription, Pay::Charge.last.subscription
  end

  test "paddle charge is created and card details are set" do
    @event.payment_method = "card"
    assert_difference "Pay::Charge.count" do
      Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceeded.new.call(@event)
    end

    charge = Pay::Charge.last
    assert_equal "card", charge.payment_method_type
    assert_equal "visa", charge.brand
    assert_equal "1234", charge.last4
    assert_equal "06", charge.exp_month
    assert_equal "2022", charge.exp_year
    assert_equal "USD", charge.currency
  end

  test "paddle charge is created and paypal details are set" do
    assert_difference "Pay::Charge.count" do
      Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceeded.new.call(@event)
    end

    charge = Pay::Charge.last
    assert_equal "paypal", charge.payment_method_type
    assert_equal "PayPal", charge.brand
    assert_nil charge.last4
    assert_nil charge.exp_month
    assert_nil charge.exp_year
  end

  test "user default payment method updated when a charge succeeds" do
    assert_difference "Pay::Charge.count" do
      Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceeded.new.call(@event)
    end

    @pay_customer.reload_default_payment_method

    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "visa", @pay_customer.default_payment_method.brand
    assert_equal "1234", @pay_customer.default_payment_method.last4
    assert_equal "06", @pay_customer.default_payment_method.exp_month
    assert_equal "2022", @pay_customer.default_payment_method.exp_year
  end

  test "a charge isn't created if no corresponding user can be found" do
    @pay_customer.update!(processor_id: "does-not-exist")
    assert_no_difference "Pay::Charge.count" do
      Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceeded.new.call(@event)
    end
  end

  test "a charge isn't created if it already exists" do
    @pay_customer.charges.create!(processor_id: @event.subscription_payment_id, amount: 1_00, payment_method_type: @event.payment_method)

    assert_no_difference "Pay::Charge.count" do
      Pay::PaddleClassic::Webhooks::SubscriptionPaymentSucceeded.new.call(@event)
    end
  end
end
