require "test_helper"

class Pay::Stripe::Webhooks::ChargeUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("charge.updated")
  end

  test "a charge is updated" do
    pay_customers(:stripe).update(processor_id: @event.data.object.customer)

    ::Stripe::ChargeService.any_instance.expects(:retrieve).returns(@event.data.object)
    ::Stripe::InvoicePaymentService.any_instance.expects(:list).returns([])

    charge = Pay::Stripe::Charge.find_by(processor_id: @event.data.object.id)
    assert_nil charge.object
    Pay::Stripe::Webhooks::ChargeUpdated.new.call(@event)
    assert_not_nil charge.reload.object
  end
end
