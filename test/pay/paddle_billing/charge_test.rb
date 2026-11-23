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
    charge = Pay::PaddleBilling::Charge.sync("txn_01jmz9mapg8c84b1w9bx4dxd2g")
    adjustment = charge.refund!

    assert_requested :post, "https://sandbox-api.paddle.com/adjustments",
      body: {transaction_id: "txn_01jmz9mapg8c84b1w9bx4dxd2g", action: "refund", reason: "Refund", type: "full"}
    assert_equal "full", adjustment.type
    assert_equal "pending_approval", adjustment.status
    assert_equal "1900", adjustment.totals.total
    # Paddle approves refunds later, and the adjustment webhooks record them
    assert_equal 0, charge.reload.amount_refunded
  end

  test "paddle billing partial refund refunds the line item and blocks refunds until approved" do
    charge = Pay::PaddleBilling::Charge.sync("txn_01jjffa06k6bezq0axxaadrje2")
    adjustment = charge.refund!(5_00, reason: "Customer request")

    assert_requested :post, "https://sandbox-api.paddle.com/adjustments",
      body: {
        transaction_id: "txn_01jjffa06k6bezq0axxaadrje2", action: "refund", reason: "Customer request", type: "partial",
        items: [{item_id: "txnitm_01jjffa0gxakk4teygjb7am1vh", type: "partial", amount: "500"}]
      }
    assert_equal "partial", adjustment.type
    assert_equal "pending_approval", adjustment.status
    assert_equal "500", adjustment.totals.total
    assert_equal 0, charge.reload.amount_refunded

    error = assert_raises(Pay::PaddleBilling::Error) { charge.refund!(3_00) }
    assert_includes error.message, "adjustment_pending_refund_request"
  end

  test "paddle billing refund after a partial refund refunds the rest of the line item" do
    charge = paddle_billing_charge(amount_refunded: 5_00)
    ::Paddle::Transaction.stubs(:retrieve).with(id: charge.processor_id).returns(paddle_billing_transaction("txnitm_1"))
    ::Paddle::Adjustment.expects(:create).with(
      transaction_id: charge.processor_id, action: "refund", reason: "Refund", type: "partial",
      items: [{item_id: "txnitm_1", type: "partial", amount: "1400"}]
    ).returns(:adjustment)

    assert_equal :adjustment, charge.refund!
  end

  test "paddle billing refund of more than what's left refunds the rest" do
    charge = paddle_billing_charge(amount_refunded: 5_00)
    ::Paddle::Transaction.stubs(:retrieve).returns(paddle_billing_transaction("txnitm_1"))
    ::Paddle::Adjustment.expects(:create).with(has_entry(items: [{item_id: "txnitm_1", type: "partial", amount: "1400"}]))

    charge.refund!(19_00)
  end

  test "paddle billing partial refund raises with several line items" do
    charge = paddle_billing_charge
    ::Paddle::Transaction.stubs(:retrieve).returns(paddle_billing_transaction("txnitm_1", "txnitm_2"))
    ::Paddle::Adjustment.expects(:create).never

    error = assert_raises(Pay::PaddleBilling::Error) { charge.refund!(5_00) }
    assert_includes error.message, "one line item"
  end

  test "paddle billing full refund with several line items doesn't need the line items" do
    charge = paddle_billing_charge
    ::Paddle::Transaction.expects(:retrieve).never
    ::Paddle::Adjustment.expects(:create).with(transaction_id: charge.processor_id, action: "refund", reason: "Refund", type: "full")

    charge.refund!
  end

  test "paddle billing refund raises when nothing is left to refund" do
    charge = paddle_billing_charge(amount_refunded: 19_00)
    ::Paddle::Adjustment.expects(:create).never

    assert_raises(Pay::PaddleBilling::Error) { charge.refund! }
  end

  private

  def paddle_billing_charge(**attributes)
    Pay::PaddleBilling::Charge.create!({customer: @pay_customer, processor_id: "txn_123", amount: 19_00, amount_refunded: 0, currency: "usd"}.merge(attributes))
  end

  def paddle_billing_transaction(*line_item_ids)
    ::Paddle::Transaction.new(details: {line_items: line_item_ids.map { |id| {id: id} }})
  end
end
