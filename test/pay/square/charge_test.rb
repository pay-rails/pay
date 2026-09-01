require "test_helper"

class Pay::Square::ChargeTest < Pay::Square::TestCase
  setup do
    @user = users(:none)
    @pay_customer = @user.set_payment_processor(:square, square_account: "MERCHANT_1")
    @pay_customer.update!(processor_id: "sqcust_test")
    @charge = @pay_customer.charges.create!(processor_id: "pmt_test", amount: 10_00, currency: "usd", square_account: "MERCHANT_1")
  end

  test "sync re-fetches authoritative payment state from the API" do
    @charge.destroy
    stub_square(:get, "payments/pmt_test", response: {payment: square_payment_json})

    charge = Pay::Square::Charge.sync("pmt_test", pay_customer: @pay_customer)
    assert_equal 10_00, charge.amount
    assert_equal "usd", charge.currency
    assert_equal 1_00, charge.application_fee_amount
    assert_equal "MERCHANT_1", charge.square_account
    assert_equal "VISA", charge.brand
  end

  test "refund issues a refund then re-syncs amount_refunded from authoritative state" do
    stub_square(:post, "refunds", response: {refund: {id: "ref_1", status: "PENDING", payment_id: "pmt_test", amount_money: {amount: 5_00, currency: "USD"}}})
    stub_square(:get, "payments/pmt_test", response: {payment: square_payment_json(refunded_money: {amount: 5_00, currency: "USD"})})

    @charge.refund!(5_00)
    assert_equal 5_00, @charge.reload.amount_refunded
  end

  test "refund does not optimistically increment when the API rejects" do
    stub_square(:post, "refunds", status: 422, response: {errors: [{category: "INVALID_REQUEST_ERROR", code: "REFUND_AMOUNT_INVALID"}]})

    assert_raises(Pay::Square::Error) { @charge.refund!(50_00) }
    assert_equal 0, @charge.reload.amount_refunded.to_i
  end
end
