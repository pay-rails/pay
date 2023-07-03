require "test_helper"

class Pay::LemonSqueezy::Webhooks::SubscriptionPaymentRefundedTest < ActiveSupport::TestCase
  setup do
    @data = OpenStruct.new JSON.parse(File.read("test/support/fixtures/lemon_squeezy/subscription_payment_refunded.json"))
    @pay_customer = pay_customers(:lemon_squeezy)
    @pay_customer.update(processor_id: @data.user_id)
  end

  test "a charge is updated with refunded amount" do
    charge = @pay_customer.charges.create!(processor_id: @data.subscription_payment_id, amount: 16)
    Pay::LemonSqueezy::Webhooks::SubscriptionPaymentRefunded.new.call(@data)
    assert_equal (@data.gross_refund.to_f * 100).to_i, charge.reload.amount_refunded
  end

  test "a charge isn't updated with the refunded amount if a corresponding charge can't be found (obviously)" do
    charge = @pay_customer.charges.create!(processor_id: "does-not-exist", amount: 16)
    Pay::LemonSqueezy::Webhooks::SubscriptionPaymentRefunded.new.call(@data)
    assert_nil charge.reload.amount_refunded
  end
end
