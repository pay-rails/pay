require "test_helper"

class Pay::Paddle::Webhooks::SubscriptionPaymentSucceededTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle/subscription_payment_succeeded.json"))
    @pay_customer = pay_customers(:paddle)
    @pay_customer.update(processor_id: @data["user_id"])
  end

  test "a charge is created" do
    subscription_user = {
      subscription_id: 7654321,
      subscription_plan_id: 123456,
      user_id: 12345678,
      user_email: "test@example.com",
      marketing_consent: false,
      state: "active",
      signup_date: "2020-12-08 07:52:22",
      last_payment: {amount: 0, currency: "USD", date: "2020-12-08"}, linked_subscriptions: [],
      payment_information: {payment_method: "card", card_type: "Visa", last_four_digits: "0020", expiry_date: "06/2022"},
      next_payment: {amount: 0, currency: "USD", date: "2021-01-08"}
    }

    assert_difference "Pay::Charge.count" do
      PaddlePay::Subscription::User.stubs(:list).returns([subscription_user])
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    charge = Pay::Charge.last
    assert_equal (@data["sale_gross"].to_f * 100).to_i, charge.amount
    assert_equal "card", charge.payment_method_type
    assert_equal "Visa", charge.brand
    assert_equal @data["receipt_url"], charge.paddle_receipt_url
  end

  test "paddle charge is associated with subscription" do
    @pay_customer.subscription.update!(processor_id: @data["subscription_id"])
    assert_difference "Pay::Charge.count" do
      PaddlePay::Subscription::User.stubs(:list).returns(:nil)
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    assert_equal @pay_customer.subscription, Pay::Charge.last.subscription
  end

  test "a charge is created and card details are set" do
    @data["payment_method"] = "card"
    subscription_user = {
      subscription_id: 7654321,
      plan_id: 123456,
      user_id: 12345678,
      user_email: "test@example.com",
      marketing_consent: false,
      update_url: "https://example.com",
      cancel_url: "https://example.com",
      state: "active",
      signup_date: "2020-12-08 07:52:22",
      last_payment: {amount: 0, currency: "USD", date: "2020-12-08"}, linked_subscriptions: [],
      payment_information: {payment_method: "card", card_type: "Visa", last_four_digits: "0020", expiry_date: "06/2022"},
      next_payment: {amount: 0, currency: "USD", date: "2021-01-08"}
    }

    assert_difference "Pay::Charge.count" do
      PaddlePay::Subscription::User.stubs(:list).returns([subscription_user])
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    charge = Pay::Charge.last
    assert_equal "card", charge.payment_method_type
    assert_equal "Visa", charge.brand
    assert_equal "0020", charge.last4
    assert_equal "06", charge.exp_month
    assert_equal "2022", charge.exp_year
    assert_equal "USD", charge.currency
  end

  test "a charge is created and paypal details are set" do
    subscription_user = {
      subscription_id: 7654321,
      plan_id: 123456,
      user_id: 12345678,
      user_email: "test@example.com",
      marketing_consent: false,
      update_url: "https://example.com",
      cancel_url: "https://example.com",
      state: "active",
      signup_date: "2020-12-08 07:52:22",
      last_payment: {amount: 0, currency: "USD", date: "2020-12-08"}, linked_subscriptions: [],
      payment_information: {payment_method: "paypal"},
      next_payment: {amount: 0, currency: "USD", date: "2021-01-08"}
    }

    assert_difference "Pay::Charge.count" do
      PaddlePay::Subscription::User.stubs(:list).returns([subscription_user])
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    charge = Pay::Charge.last
    assert_equal "paypal", charge.payment_method_type
    assert_equal "PayPal", charge.brand
    assert_nil charge.last4
    assert_nil charge.exp_month
    assert_nil charge.exp_year
  end

  test "user default payment method updated when a charge succeeds" do
    subscription_user = {
      subscription_id: 7654321,
      plan_id: 123456,
      user_id: 12345678,
      user_email: "test@example.com",
      marketing_consent: false,
      update_url: "https://example.com",
      cancel_url: "https://example.com",
      state: "active",
      signup_date: "2020-12-08 07:52:22",
      last_payment: {amount: 0, currency: "USD", date: "2020-12-08"}, linked_subscriptions: [],
      payment_information: {payment_method: "card", card_type: "Visa", last_four_digits: "0020", expiry_date: "06/2022"},
      next_payment: {amount: 0, currency: "USD", date: "2021-01-08"}
    }

    assert_difference "Pay::Charge.count" do
      PaddlePay::Subscription::User.stubs(:list).returns([subscription_user])
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    @pay_customer.reload_default_payment_method

    assert_equal "card", @pay_customer.default_payment_method.payment_method_type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
    assert_equal "0020", @pay_customer.default_payment_method.last4
    assert_equal "06", @pay_customer.default_payment_method.exp_month
    assert_equal "2022", @pay_customer.default_payment_method.exp_year
  end

  test "a charge isn't created if no corresponding user can be found" do
    @pay_customer.update!(processor_id: "does-not-exist")
    assert_no_difference "Pay::Charge.count" do
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end
  end

  test "a charge isn't created if it already exists" do
    @pay_customer.charges.create!(processor_id: @data["subscription_payment_id"], amount: 1_00, payment_method_type: @data["payment_method"])

    assert_no_difference "Pay::Charge.count" do
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end
  end
end
