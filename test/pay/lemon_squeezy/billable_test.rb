require "test_helper"

class Pay::LemonSqueezy::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lemon_squeezy)
  end

  test "lemon squeezy cannot create a charge" do
    assert_raises(Pay::Error) { @pay_customer.charge(1000) }
  end

  test "retrieving a lemon squeezy subscription" do
    subscription = ::LemonSqueezy::Subscription.retrieve(id: "253735")
    assert_equal @pay_customer.processor_subscription("253735").id, subscription.id
  end
end
