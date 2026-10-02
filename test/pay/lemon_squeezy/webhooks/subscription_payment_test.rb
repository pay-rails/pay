require "test_helper"

class Pay::LemonSqueezy::Webhooks::SubscriptionPaymentTest < ActiveSupport::TestCase
  test "lemon squeezy subscription_payment_success webhook" do
    charge = charge_from lemon_squeezy_event("subscription_payment_success")

    assert_equal 999, charge.amount
    assert_equal 0, charge.amount_refunded
  end

  test "lemon squeezy subscription_payment_refunded webhook" do
    charge = charge_from lemon_squeezy_event("subscription_payment_refunded")

    assert_equal 999, charge.amount
    assert_equal 999, charge.amount_refunded
  end

  private

  # Processes the event for a customer with a matching subscription and returns the charge it creates
  def charge_from(event)
    pay_customer = users(:none).set_payment_processor :lemon_squeezy, processor_id: event.customer_id
    pay_customer.subscriptions.create!(processor_id: event.subscription_id, name: Pay.default_product_name, processor_plan: "Default", status: :active)

    assert_difference "Pay::Charge.count" do
      Pay::LemonSqueezy::Webhooks::SubscriptionPayment.new.call(event)
    end

    Pay::Charge.last
  end
end
