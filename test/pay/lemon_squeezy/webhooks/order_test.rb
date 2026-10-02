require "test_helper"

class Pay::LemonSqueezy::Webhooks::OrderTest < ActiveSupport::TestCase
  setup do
    @event = lemon_squeezy_event("order_created")
    users(:none).set_payment_processor :lemon_squeezy, processor_id: @event.customer_id
  end

  test "lemon squeezy order_created webhook" do
    ::LemonSqueezy::Subscription.expects(:list).returns(ActiveSupport::InheritableOptions.new({data: []}))

    assert_difference "Pay::Charge.count" do
      Pay::LemonSqueezy::Webhooks::Order.new.call(@event)
    end

    assert_equal @event.total, Pay::Charge.last.amount
  end
end
