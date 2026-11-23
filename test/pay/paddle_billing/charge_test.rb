require "test_helper"

class Pay::PaddleBilling::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_billing)
    @pay_customer.update!(processor_id: "ctm_01hb6qy0jkmxx9xat02mzzzrc1")
  end

  test "paddle billing sync records approved refunds" do
    charge = Pay::PaddleBilling::Charge.sync("txn_01jq7creqqfcg229vgb4xvjht7")
    assert_equal 19_00, charge.amount_refunded
    assert charge.full_refund?
  end

  test "paddle billing sync ignores refunds pending approval" do
    charge = Pay::PaddleBilling::Charge.sync("txn_01jsq72pnpf4a5vs3t4238srz2")
    assert_equal 19_00, charge.amount
    assert_equal 0, charge.amount_refunded
    assert_not charge.refunded?
  end

  test "paddle billing syncs the charge when a refund is approved" do
    Pay::PaddleBilling::Charge.expects(:sync).with("txn_01jq7creqqfcg229vgb4xvjht7")
    Pay::PaddleBilling::Webhooks::Adjustment.new.call(paddle_billing_event("adjustment.updated"))
  end

  test "paddle billing ignores refunds pending approval" do
    Pay::PaddleBilling::Charge.expects(:sync).never
    Pay::PaddleBilling::Webhooks::Adjustment.new.call(paddle_billing_event("adjustment.created"))
  end

  test "paddle billing refund of an unrefunded charge is a full refund" do
    charge = Pay::PaddleBilling::Charge.sync("txn_01jdjd23jdw6rr577nvb5x2zpv")
    adjustment = charge.refund!

    assert_requested :post, "https://sandbox-api.paddle.com/adjustments",
      body: {transaction_id: "txn_01jdjd23jdw6rr577nvb5x2zpv", action: "refund", reason: "Refund", type: "full"}
    assert_equal "full", adjustment.type
    assert_equal "pending_approval", adjustment.status
    assert_equal "1900", adjustment.totals.total
    # Paddle approves refunds later, and the adjustment webhooks record them
    assert_equal 0, charge.reload.amount_refunded
  end

  test "paddle billing partial refund refunds the line item and blocks refunds until approved" do
    charge = Pay::PaddleBilling::Charge.sync("txn_01jfzmzpqg4fykjpfpft0c2pyg")
    adjustment = charge.refund!(5_00, reason: "Customer request")

    assert_requested :post, "https://sandbox-api.paddle.com/adjustments",
      body: {
        transaction_id: "txn_01jfzmzpqg4fykjpfpft0c2pyg", action: "refund", reason: "Customer request", type: "partial",
        items: [{item_id: "txnitm_01jfzmzq1xfnhpgm061sr4ex70", type: "partial", amount: "500"}]
      }
    assert_equal "partial", adjustment.type
    assert_equal "pending_approval", adjustment.status
    assert_equal "500", adjustment.totals.total
    assert_equal 0, charge.reload.amount_refunded

    error = assert_raises(Pay::PaddleBilling::Error) { charge.refund!(3_00) }
    assert_includes error.message, "adjustment_pending_refund_request"
  end

  # txn_01jsq72pnpf4a5vs3t4238srz2 has an approved $5.00 refund that this charge doesn't know about yet
  test "paddle billing refund after a partial refund Pay hasn't synced refunds the rest of the line item" do
    charge = paddle_billing_charge(processor_id: "txn_01jsq72pnpf4a5vs3t4238srz2")
    adjustment = charge.refund!

    assert_requested :post, "https://sandbox-api.paddle.com/adjustments",
      body: {
        transaction_id: "txn_01jsq72pnpf4a5vs3t4238srz2", action: "refund", reason: "Refund", type: "partial",
        items: [{item_id: "txnitm_01jsq72pzjfhzgv3sk278chpwd", type: "partial", amount: "1400"}]
      }
    assert_equal "pending_approval", adjustment.status
    assert_equal "1400", adjustment.totals.total
  end

  test "paddle billing refund of more than what's left raises" do
    charge = paddle_billing_charge
    ::Paddle::Transaction.stubs(:retrieve).returns(paddle_billing_transaction("txnitm_1", refunded: 5_00))
    ::Paddle::Adjustment.expects(:create).never

    error = assert_raises(Pay::PaddleBilling::Error) { charge.refund!(19_00) }
    assert_includes error.message, "between 1 and 1400"
  end

  test "paddle billing partial refund raises with several line items" do
    charge = paddle_billing_charge
    ::Paddle::Transaction.stubs(:retrieve).returns(paddle_billing_transaction("txnitm_1", "txnitm_2"))
    ::Paddle::Adjustment.expects(:create).never

    error = assert_raises(Pay::PaddleBilling::Error) { charge.refund!(5_00) }
    assert_includes error.message, "one line item"
  end

  test "paddle billing full refund works with several line items" do
    charge = paddle_billing_charge
    ::Paddle::Transaction.stubs(:retrieve).returns(paddle_billing_transaction("txnitm_1", "txnitm_2"))
    ::Paddle::Adjustment.expects(:create).with(transaction_id: charge.processor_id, action: "refund", reason: "Refund", type: "full")

    charge.refund!
  end

  test "paddle billing refund raises when nothing is left to refund" do
    charge = paddle_billing_charge
    ::Paddle::Transaction.stubs(:retrieve).returns(paddle_billing_transaction("txnitm_1", refunded: 19_00))
    ::Paddle::Adjustment.expects(:create).never

    assert_raises(Pay::PaddleBilling::Error) { charge.refund! }
  end

  private

  def paddle_billing_charge(**attributes)
    Pay::PaddleBilling::Charge.create!({customer: @pay_customer, processor_id: "txn_123", amount: 19_00, amount_refunded: 0, currency: "usd"}.merge(attributes))
  end

  def paddle_billing_transaction(*line_item_ids, refunded: 0)
    ::Paddle::Transaction.new(
      details: {line_items: line_item_ids.map { |id| {id: id} }},
      adjustments_totals: {breakdown: {refund: refunded.to_s}}
    )
  end
end
