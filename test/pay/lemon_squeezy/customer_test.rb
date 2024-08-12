require "test_helper"

class Pay::LemonSqueezy::CustomerTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lemon_squeezy)
  end

  test "lemon squeezy cannot create a charge" do
    assert_raises(Pay::Error) { @pay_customer.charge(1000) }
  end
end
