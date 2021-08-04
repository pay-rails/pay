require "test_helper"

class Pay::Stripe::Webhooks::CustomerDeletedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/customer_deleted_event.json")
  end

  test "a customers subscription information is nulled out upon deletion" do
    pay_customer = pay_customers(:stripe)
    pay_customer.update(processor_id: @event.data.object.id)
    pay_customer.subscriptions.create!(
      processor_id: "sub_someid",
      name: "default",
      processor_plan: "some-plan",
      trial_ends_at: 3.days.from_now,
      status: "active"
    )

    assert_difference "Pay::Subscription.count", -2 do
      assert_difference "Pay::Customer.count", -1 do
        Pay::Stripe::Webhooks::CustomerDeleted.new.call(@event)
      end
    end
  end
end
