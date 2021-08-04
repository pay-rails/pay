require "test_helper"

class Pay::Paddle::Charge::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle)
  end

  test "paddle can get paddle charge" do
    charge = @pay_customer.charges.create!(
      processor_id: "11018517",
      amount: 119,
      card_type: "card",
      paddle_receipt_url: "https://my.paddle.com/receipt/15124577-11018517/57042319-chre8cc6b3d11d5-1696e10c7c",
      created_at: Time.zone.now
    )
    paddle_charge = charge.processor_charge
    assert_equal charge.processor_id, paddle_charge[:id].to_s
  end

  test "paddle can fully refund a transaction" do
    charge = @pay_customer.charges.create!(
      processor_id: "11018517",
      amount: 119,
      card_type: "card",
      paddle_receipt_url: "https://my.paddle.com/receipt/15124577-11018517/57042319-chre8cc6b3d11d5-1696e10c7c",
      created_at: Time.zone.now
    )

    charge.refund!
    assert_equal 119, charge.amount_refunded
  end

  test "paddle cannot refund a transaction without payment" do
    charge = @pay_customer.charges.create!(
      processor_id: "does-not-exist",
      amount: 119,
      card_type: "card",
      paddle_receipt_url: "https://my.paddle.com/receipt/15124577-11018517/57042319-chre8cc6b3d11d5-1696e10c7c",
      created_at: Time.zone.now
    )

    assert_raises(Pay::Error) { charge.refund! }
  end
end
