require "test_helper"

class Pay::PaddleClassic::Webhooks::SubscriptionPaymentRefundedTest < ActiveSupport::TestCase
  setup do
    @event = paddle_classic_event("subscription_payment_refunded")
    @pay_customer = pay_customers(:paddle_classic)
    @pay_customer.update(processor_id: @event.user_id)
  end

  test "a charge is updated with refunded amount" do
    charge = @pay_customer.charges.create!(processor_id: @event.subscription_payment_id, amount: 19_99)
    @event.gross_refund = "19.99"
    Pay::PaddleClassic::Webhooks::SubscriptionPaymentRefunded.new.call(@event)
    assert_equal 19_99, charge.reload.amount_refunded
  end

  test "a charge isn't updated with the refunded amount if a corresponding charge can't be found (obviously)" do
    charge = @pay_customer.charges.create!(processor_id: "does-not-exist", amount: 16)
    Pay::PaddleClassic::Webhooks::SubscriptionPaymentRefunded.new.call(@event)
    assert_nil charge.reload.amount_refunded
  end
end
