require "test_helper"

class Pay::Paddle::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle)
  end

  test "paddle can create a charge" do
    charge = @pay_customer.charge(1000, {charge_name: "Test"})
    assert_equal Pay::Charge, charge.class
    assert_equal 1000, charge.amount
  end

  test "paddle cannot create a charge without charge_name" do
    assert_raises(Pay::Error) { @pay_customer.charge(1000) }
  end

  test "retriving a paddle subscription" do
    subscription = ::PaddlePay::Subscription::User.list({subscription_id: "3576390"}, {}).try(:first)
    assert_equal @pay_customer.processor_subscription("3576390").subscription_id, subscription[:subscription_id]
  end

  test "paddle can sync payment information" do
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
    PaddlePay::Subscription::User.stubs(:list).returns([subscription_user])

    @pay_customer.sync_payment_method

    assert_equal "card", @pay_customer.default_payment_method.type
    assert_equal "Visa", @pay_customer.default_payment_method.brand
    assert_equal "0020", @pay_customer.default_payment_method.last4
    assert_equal "06", @pay_customer.default_payment_method.exp_month
    assert_equal "2022", @pay_customer.default_payment_method.exp_year
  end
end
