require "test_helper"

class Pay::PaddleClassic::Charge::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_classic)
  end

  test "paddle classic can get paddle charge" do
    charge = @pay_customer.charges.create!(
      processor_id: "11018517",
      amount: 119,
      payment_method_type: "card",
      paddle_receipt_url: "https://my.paddle.com/receipt/15124577-11018517/57042319-chre8cc6b3d11d5-1696e10c7c",
      created_at: Time.zone.now
    )
    paddle_charge = charge.api_record
    assert_equal charge.processor_id, paddle_charge[:id].to_s
  end

  test "paddle classic can fully refund a transaction" do
    charge = @pay_customer.charges.create!(
      processor_id: "11018517",
      amount: 119,
      payment_method_type: "card",
      paddle_receipt_url: "https://my.paddle.com/receipt/15124577-11018517/57042319-chre8cc6b3d11d5-1696e10c7c",
      created_at: Time.zone.now
    )

    charge.refund!
    assert_equal 119, charge.amount_refunded
  end

  test "paddle classic cannot refund a transaction without payment" do
    charge = @pay_customer.charges.create!(
      processor_id: "does-not-exist",
      amount: 119,
      payment_method_type: "card",
      paddle_receipt_url: "https://my.paddle.com/receipt/15124577-11018517/57042319-chre8cc6b3d11d5-1696e10c7c",
      created_at: Time.zone.now
    )

    assert_raises(Pay::PaddleClassic::Error) { charge.refund! }
  end
end
