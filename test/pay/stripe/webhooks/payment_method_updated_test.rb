require "test_helper"

class Pay::Stripe::Webhooks::PaymentMethodUpdatedtest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/payment_method.updated.json")
  end

  test "update_card_from stripe is called upon customer update" do
    user = User.create!(
      email: "gob@bluth.com",
      processor: :stripe,
      processor_id: @event.data.object.customer
    )
    user.subscriptions.create!(
      processor: :stripe,
      processor_id: "sub_someid",
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay::Stripe::Billable.any_instance.expects(:sync_card_from_stripe)
    Pay::Stripe::Webhooks::PaymentMethodUpdated.new.call(@event)
  end

  test "update_card_from stripe is not called if user can't be found" do
    user = User.create!(
      email: "gob@bluth.com",
      processor: :stripe,
      processor_id: "does-not-exist"
    )
    user.subscriptions.create!(
      processor: :stripe,
      processor_id: "sub_someid",
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay::Stripe::Billable.any_instance.expects(:sync_card_from_stripe).never
    Pay::Stripe::Webhooks::PaymentMethodUpdated.new.call(@event)
  end
end
