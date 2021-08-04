require "test_helper"

class Pay::Stripe::Webhooks::CustomerUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/customer_updated_event.json")
  end

  test "update_card_from stripe is called upon customer update" do
    pay_customer = pay_customers(:stripe)
    pay_customer.update(processor_id: @event.data.object.id)
    pay_customer.subscriptions.create!(
      processor_id: "sub_someid",
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay::Stripe::Billable.any_instance.expects(:sync_card_from_stripe)
    Pay::Stripe::Webhooks::CustomerUpdated.new.call(@event)
  end

  test "update_card_from stripe is not called if user can't be found" do
    pay_customer = pay_customers(:stripe)
    pay_customer.update(processor_id: "does-not-exist")
    pay_customer.subscriptions.create!(
      processor_id: "sub_someid",
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay::Stripe::Billable.any_instance.expects(:sync_card_from_stripe).never
    Pay::Stripe::Webhooks::CustomerUpdated.new.call(@event)
  end
end
