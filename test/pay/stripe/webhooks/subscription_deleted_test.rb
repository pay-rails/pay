require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionDeletedTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/subscription_deleted_event.json"), object_class: OpenStruct)
  end

  test "it sets ends_at on the subscription" do
    @user = User.create!(
      email: "gob@bluth.com",
      processor: :stripe,
      processor_id: @event.data.object.customer
    )
    @user.subscriptions.create!(
      processor: :stripe,
      processor_id: @event.data.object.id,
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay.subscription_model.any_instance.expects(:update!).with(ends_at: Time.at(@event.data.object.ended_at))
    Pay::Stripe::Webhooks::SubscriptionDeleted.new.call(@event)
  end

  test "it doesn't set ends_at on the subscription if it's already set" do
    @user = User.create!(
      email: "gob@bluth.com",
      processor: :stripe,
      processor_id: @event.data.object.customer
    )
    @user.subscriptions.create!(
      processor: :stripe,
      processor_id: @event.data.object.id,
      name: "default",
      processor_plan: "some-plan",
      ends_at: Time.zone.now,
      status: "active"
    )

    Pay.subscription_model.any_instance.expects(:update!).with(ends_at: Time.at(@event.data.object.ended_at)).never
    Pay::Stripe::Webhooks::SubscriptionDeleted.new.call(@event)
  end

  test "it doesn't set ends_at on the subscription if it can't find the subscription" do
    @user = User.create!(
      email: "gob@bluth.com",
      processor: :stripe,
      processor_id: @event.data.object.customer
    )
    @user.subscriptions.create!(
      processor: :stripe,
      processor_id: "does-not-exist",
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )

    Pay.subscription_model.any_instance.expects(:update!).with(ends_at: Time.at(@event.data.object.ended_at)).never
    Pay::Stripe::Webhooks::SubscriptionDeleted.new.call(@event)
  end

  # test "it does nothing if subscription can't be found" do
  #   @user = User.create!(email: 'gob@bluth.com', processor: :stripe, processor_id: @event.data.object.customer)
  #   subscription = @user.subscriptions.create!(processor: :stripe, processor_id: 'does-not-exist', name: 'default', processor_plan: 'some-plan')
  # end
end
