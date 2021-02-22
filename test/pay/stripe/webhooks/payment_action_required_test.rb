require "test_helper"

class Pay::Stripe::Webhooks::PaymentActionRequiredTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/invoice.payment_action_required.json"), object_class: OpenStruct)

    # Create user and subscription
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    @subscription = @user.subscriptions.create!(
      processor: :stripe,
      processor_id: @event.data.object.subscription,
      name: "default",
      processor_plan: "some-plan",
      status: "requires_action"
    )
  end

  test "it sends an email" do
    assert_enqueued_jobs 1 do
      Pay::Stripe::Webhooks::PaymentActionRequired.new.call(@event)
    end
  end

  test "ignores if subscription doesn't exist" do
    @subscription.destroy!
    assert_no_enqueued_jobs do
      Pay::Stripe::Webhooks::PaymentActionRequired.new.call(@event)
    end
  end
end
