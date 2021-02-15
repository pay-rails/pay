require "test_helper"

class Pay::Paddle::Webhooks::SubscriptionPaymentSucceededTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle/subscription_payment_succeeded.json"))
  end

  test "a charge is created" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])

    assert_difference "Pay.charge_model.count" do
      PaddlePay::Subscription::User.stubs(:list).returns(:nil)
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    charge = Pay.charge_model.last
    assert_equal Integer(@data["sale_gross"].to_f * 100), charge.amount
    assert_equal @data["payment_method"], charge.card_type
    assert_equal @data["receipt_url"], charge.paddle_receipt_url
  end

  test "a charge is created and card details are set" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])

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
      payment_information: {payment_method: "card", card_type: "visa", last_four_digits: "0020", expiry_date: "06/2022"},
      next_payment: {amount: 0, currency: "USD", date: "2021-01-08"}
    }

    assert_difference "Pay.charge_model.count" do
      PaddlePay::Subscription::User.stubs(:list).returns([subscription_user])
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    charge = Pay.charge_model.last
    assert_equal "visa", charge.card_type
    assert_equal "0020", charge.card_last4
    assert_equal "06", charge.card_exp_month
    assert_equal "2022", charge.card_exp_year
  end

  test "a charge is created and paypal details are set" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])

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

    assert_difference "Pay.charge_model.count" do
      PaddlePay::Subscription::User.stubs(:list).returns([subscription_user])
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    charge = Pay.charge_model.last
    assert_equal "PayPal", charge.card_type
    assert_nil charge.card_last4
    assert_nil charge.card_exp_month
    assert_nil charge.card_exp_year
  end

  test "a charge is created and user payment information are updated" do
    user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])

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
      payment_information: {payment_method: "card", card_type: "visa", last_four_digits: "0020", expiry_date: "06/2022"},
      next_payment: {amount: 0, currency: "USD", date: "2021-01-08"}
    }

    assert_difference "Pay.charge_model.count" do
      PaddlePay::Subscription::User.stubs(:list).returns([subscription_user])
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end

    assert_equal "visa", user.reload.card_type
    assert_equal "0020", user.reload.card_last4
    assert_equal "06", user.reload.card_exp_month
    assert_equal "2022", user.reload.card_exp_year
  end

  test "a charge isn't created if no corresponding user can be found" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: "does-not-exist")

    assert_no_difference "Pay.charge_model.count" do
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end
  end

  test "a charge isn't created if it already exists" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @data["user_id"])

    @user.charges.create!(amount: 100, processor: :paddle, processor_id: @data["subscription_payment_id"], card_type: @data["payment_method"])

    assert_no_difference "Pay.charge_model.count" do
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new.call(@data)
    end
  end
end
