require "test_helper"

class Pay::Paddle::Webhooks::SubscriptionPaymentRefundedTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle/subscription_payment_refunded.json"))
  end

  test "a charge is updated with refunded amount" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])
    charge = @user.charges.create!(processor: :paddle, processor_id: @data["subscription_payment_id"], amount: 16, card_type: "card")

    Pay::Paddle::Webhooks::SubscriptionPaymentRefunded.new.call(@data)

    assert_equal Integer(@data["gross_refund"].to_f * 100), charge.reload.amount_refunded
  end

  test "a charge isn't updated with the refunded amount if a corresponding charge can't be found (obviously)" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: "does-not-exist")
    charge = @user.charges.create!(processor: :paddle, processor_id: "doesntexist", amount: 500, card_type: "card")

    assert_nil charge.reload.amount_refunded
  end
end
