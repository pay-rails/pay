require "test_helper"

class Pay::PaddleBilling::CustomerTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_billing)
  end

  test "paddle cannot create a charge without options" do
    error = assert_raises(Pay::PaddleBilling::Error) { @pay_customer.charge(1000) }
    assert_kind_of Paddle::ErrorGenerator, error.cause
  end

  test "paddle billing subscribe is not supported" do
    assert_raises(Pay::NotSupportedError) { @pay_customer.subscribe }
  end
end
