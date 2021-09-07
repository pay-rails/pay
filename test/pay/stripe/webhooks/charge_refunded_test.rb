require "test_helper"

class Pay::Stripe::Webhooks::ChargeRefundedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("charge.refunded")
    pay_charges(:stripe).update(id: @event.data.object.id)
    pay_customers(:stripe).update(processor_id: @event.data.object.customer)
  end

  test "a charge is updated with refunded amount" do
    ::Stripe::Charge.expects(:retrieve).returns(@event.data.object)

    assert_enqueued_jobs 1 do
      Pay::Stripe::Webhooks::ChargeRefunded.new.call(@event)
    end
  end
end
