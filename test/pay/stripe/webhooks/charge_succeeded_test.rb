require "test_helper"

class Pay::Stripe::Webhooks::ChargeSucceededTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("charge.succeeded")
  end

  test "a charge is created" do
    pay_customers(:stripe).update(processor_id: @event.data.object.customer)

    ::Stripe::Charge.expects(:retrieve).returns(@event.data.object)
    ::Stripe::InvoicePayment.expects(:list).returns([])

    # Make sure enqueues the receipt email
    assert_enqueued_jobs 1 do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
    end
  end
end
