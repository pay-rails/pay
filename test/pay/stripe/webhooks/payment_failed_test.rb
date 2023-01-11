require "test_helper"

class Pay::Stripe::Webhooks::PaymentFailedTest < ActiveSupport::TestCase
  setup do
    @payment_failed_event = stripe_event("invoice.payment_failed")
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: @payment_failed_event.data.object.customer)
  end

  test "customer should receive payment failed email if setting is enabled" do
    Pay.emails.payment_failed = true # Default is true, setting here for clarity

    create_subscription(processor_id: @payment_failed_event.data.object.subscription)
    mailer = Pay::Stripe::Webhooks::PaymentFailed.new.call(@payment_failed_event)

    assert mailer.arguments.include?("payment_failed")
    assert_enqueued_emails 1
  end

  private

  def create_subscription(processor_id:)
    @pay_customer.subscriptions.create!(processor_id: processor_id, name: "default", processor_plan: "some-plan", status: "active")
  end
end
