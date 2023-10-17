require "test_helper"

class Pay::Stripe::Webhooks::CustomerDeletedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("customer.deleted")
  end

  test "stripe customer delete marks pay customer deleted" do
    pay_customer = pay_customers(:stripe)
    pay_customer.update!(processor_id: @event.data.object.id)
    pay_customer.payment_methods.create!(processor_id: "pm_fake")
    pay_subscription = pay_customer.subscriptions.create!(
      processor_id: "sub_someid",
      name: "default",
      processor_plan: "some-plan",
      trial_ends_at: 3.days.from_now,
      status: "active"
    )

    Pay::Stripe::Webhooks::CustomerDeleted.new.call(@event)

    pay_customer.reload
    pay_subscription.reload

    refute pay_customer.default?
    assert pay_customer.deleted_at?
    assert_empty pay_customer.payment_methods
    assert pay_subscription.canceled?
  end

  test "stripe customer deleted webhook does nothing if customer not in database" do
    assert_nothing_raised do
      Pay::Stripe::Webhooks::CustomerDeleted.new.call(@event)
    end
  end
end
