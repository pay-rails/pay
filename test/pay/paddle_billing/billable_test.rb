require "test_helper"

class Pay::PaddleBilling::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:paddle_billing)
  end

  test "paddle cannot create a charge without options" do
    assert_raises(Pay::Error) { @pay_customer.charge(1000) }
  end

  test "retrieving a paddle billing subscription" do
    subscription = ::Paddle::Subscription.retrieve(id: "sub_01hd1drf5htjz45yt2346anmqt")
    assert_equal @pay_customer.processor_subscription("sub_01hd1drf5htjz45yt2346anmqt").id, subscription.id
  end
end
