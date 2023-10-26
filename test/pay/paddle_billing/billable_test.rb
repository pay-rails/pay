require "test_helper"

class Pay::PaddleBilling::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_billing)
  end

  test "paddle cannot create a charge without options" do
    assert_raises(Pay::Error) { @pay_customer.charge(1000) }
  end
end
