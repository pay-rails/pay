require "test_helper"

class Pay::Stripe::Webhooks::ChargeRefundedTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/charge_refunded_event.json"), object_class: OpenStruct)
  end

  test "a charge is updated with refunded amount" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    charge = @user.charges.create!(processor: :stripe, processor_id: @event.data.object.id, amount: 500, card_type: "Visa", card_last4: "4444", card_exp_month: 1, card_exp_year: 2019)

    Pay::Stripe::Webhooks::ChargeRefunded.new.call(@event)

    assert_equal 500, charge.reload.amount_refunded
  end

  test "a charge isn't updated with the refunded amount if a corresponding charge can't be found (obviously)" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: "does-not-exist")
    charge = @user.charges.create!(processor: :stripe, processor_id: "doesntexist", amount: 500, card_type: "Visa", card_last4: "4444", card_exp_month: 1, card_exp_year: 2019)

    assert_nil charge.reload.amount_refunded
  end
end
