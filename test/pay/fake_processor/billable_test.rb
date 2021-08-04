require "test_helper"

class Pay::FakeProcessor::Billable::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:fake)
  end

  test "doesn't allow fake processor by default" do
    assert_raises Pay::Error do
      users(:none).set_payment_processor :fake_processor
    end
  end

  test "allows fake processor if enabled" do
    assert_nothing_raised do
      users(:none).set_payment_processor :fake_processor, allow_fake: true
    end
  end

  test "fake processor customer" do
    assert_equal @pay_customer, @pay_customer.customer
  end

  test "fake processor charge" do
    assert_difference "Pay::Charge.count" do
      @pay_customer.charge(10_00)
    end
  end

  test "fake processor subscribe" do
    assert_difference "Pay::Subscription.count" do
      @pay_customer.subscribe
    end
  end
end
