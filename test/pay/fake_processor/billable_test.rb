require "test_helper"

class Pay::FakeProcessor::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.create!(email: "gob@bluth.com", processor: :fake_processor, processor_id: "17368056")
  end

  test "fake processor customer" do
    assert_equal @billable, @billable.payment_processor.customer
  end

  test "fake processor charge" do
    assert_difference "Pay::Charge.count" do
      @billable.charge(10_00)
    end
  end

  test "fake processor subscribe" do
    assert_difference "Pay::Subscription.count" do
      @billable.subscribe
    end
  end
end
