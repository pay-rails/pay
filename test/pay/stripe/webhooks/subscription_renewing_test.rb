require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionRenewingTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/subscription_renewing_event.json"), object_class: OpenStruct)

    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
  end

  test "an email is sent to the user when subscription is renewing" do
    create_subscription(processor_id: @event.data.object.subscription)
    # Time.zone.at(@event.data.object.next_payment_attempt)

    Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    assert_enqueued_emails 1
  end

  test "an email is not sent when subscription can't be found" do
    create_subscription(processor_id: "does-not-exist")

    assert_no_enqueued_emails do
      Pay::Stripe::Webhooks::SubscriptionRenewing.new.call(@event)
    end
  end

  def create_subscription(processor_id:)
    @user.subscriptions.create!(processor: :stripe, processor_id: processor_id, name: "default", processor_plan: "some-plan", status: "active")
  end
end
