require "test_helper"

class Pay::Stripe::Webhooks::CustomerUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/customer_updated_event.json"), object_class: OpenStruct)
  end

  test "update_card_from stripe is called upon customer update" do
    user = User.create!(
      email: "gob@bluth.com",
      processor: :stripe,
      processor_id: @event.data.object.id
    )
    user.subscriptions.create!(
      processor: :stripe,
      processor_id: "sub_someid",
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    User.any_instance.expects(:sync_card_from_stripe)
    Pay::Stripe::Webhooks::CustomerUpdated.new.call(@event)
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

    User.any_instance.expects(:sync_card_from_stripe).never
    Pay::Stripe::Webhooks::CustomerUpdated.new.call(@event)
  end
end
