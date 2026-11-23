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
end
