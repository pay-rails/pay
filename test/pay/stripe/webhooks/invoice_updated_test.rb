require "test_helper"

class Pay::Stripe::Webhooks::InvoiceUpdatedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("invoice.updated")
    @invoice = @event.data.object
    @pay_customer = pay_customers(:stripe)
    @subscription_id = @invoice.parent.subscription_details.subscription
    @local_subscription = create_subscription(processor_id: @subscription_id)
  end

  test "the method exits early if the event doesn't send an associated subscription_id" do
    # Set parent to nil, removing the subscription_id
    @invoice.stubs(:parent).returns(nil)

    # This should never trigger if subscription_id is nil
    Pay::Subscription.expects(:find_by_processor_and_id).never

    Pay::Stripe::Webhooks::InvoiceUpdated.new.call(@event)
  end

  test "the method exits early without a database subscription record" do
    # Mock a failed DB lookup
    Pay::Subscription.stubs(:find_by_processor_and_id).returns(nil)

    # Won't be hit if subscription doesn't exist in the database
    Pay::Stripe::Subscription.expects(:sync).never

    Pay::Stripe::Webhooks::InvoiceUpdated.new.call(@event)
  end

  test "does NOT sync if the invoice in the event is NOT the latest_invoice" do
    # Mock a subscription with a different invoice id
    mock_stripe_sub = OpenStruct.new(latest_invoice: OpenStruct.new(id: "in_another_id"))
    @local_subscription.stubs(:stripe_object).returns(mock_stripe_sub)
    
    # Use the local object to stub the request
    Pay::Subscription.stubs(:find_by_processor_and_id).returns(@local_subscription)

    Pay::Stripe::Subscription.expects(:sync).never

    Pay::Stripe::Webhooks::InvoiceUpdated.new.call(@event)
  end

  test "SUCCESSFULLY syncs when the invoice ID matches the latest_invoice ID" do
    # Mock the object with an id that matches the event invoice
    mock_stripe_sub = OpenStruct.new(latest_invoice: OpenStruct.new(id: @invoice.id))
    @local_subscription.stubs(:stripe_object).returns(mock_stripe_sub)
    
    # Use the local object to stub the request
    Pay::Subscription.stubs(:find_by_processor_and_id).returns(@local_subscription)
    
    Pay::Stripe::Subscription.expects(:sync).with(@subscription_id, stripe_account: nil).once
    
    Pay::Stripe::Webhooks::InvoiceUpdated.new.call(@event)
  end

  private

  def create_subscription(processor_id:)
    @pay_customer.subscriptions.create!(processor_id: processor_id, name: "default", processor_plan: "some-plan", status: "active")
  end
end
