require "test_helper"

class Pay::PaddleBilling::CustomerTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_billing)
  end

  test "paddle cannot create a charge without options" do
    assert_raises(Paddle::Errors::ForbiddenError) { @pay_customer.charge(1000) }
  end

  test "paddle billing subscribe is not supported" do
    assert_raises(Pay::NotSupportedError) { @pay_customer.subscribe }
  end
end
