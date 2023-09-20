require "test_helper"

class Pay::Lago::Charge::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lago)
    @charge = @pay_customer.charge(10_00)
    @charge.payment_processor.update_charge!(payment_status: "succeeded")
  end

  test "lago processor charge" do
    assert_equal @charge.processor_id, @charge.payment_processor.charge.lago_id
  end

  test "lago processor refund with premium" do
    assert_nil @charge.amount_refunded
    @charge.refund!(5_00)
    assert_equal 5_00, @charge.reload.amount_refunded
  end

  test "lago processor refund without premium" do
    assert_raises(Pay::Lago::Error, "Creating a credit note requires Lago Premium.") { @charge.refund!(5_00) }
  end
end
