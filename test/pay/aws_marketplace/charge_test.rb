require "test_helper"

class Pay::FakeProcessor::Charge::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:fake)
    @charge = @pay_customer.charge(10_00)
  end

  test "fake processor api_record" do
    assert_equal @charge, @charge.api_record
    assert_equal "card", @charge.payment_method_type
    assert_equal "Fake", @charge.brand
  end

  test "fake processor refund" do
    assert_nil @charge.amount_refunded
    @charge.refund!
    assert_equal 10_00, @charge.reload.amount_refunded
  end
end
