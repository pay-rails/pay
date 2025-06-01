require "test_helper"

class Pay::Stripe::Webhooks::PaymentActionRequiredTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("invoice.payment_action_required")

    # Create user and subscription
    pay_customers(:stripe).update!(processor_id: @event.data.object.customer)
  end

  test "it sends an email" do
    Pay::Stripe::Subscription.sync @event.data.object.subscription, object: fake_stripe_subscription(id: @event.data.object.subscription, customer: @event.data.object.customer, status: :past_due)
    ::Stripe::InvoicePayment.expects(:list).returns(::Stripe::ListObject.construct_from(
      {
        object: "list",
        data: [
          {
            id: "inpay_1234",
            object: "invoice_payment",
            amount_paid: nil,
            amount_requested: 1900,
            created: 1748762673,
            currency: "usd",
            invoice: "in_1234",
            is_default: true,
            livemode: false,
            payment: {
              payment_intent: "pi_1234",
              type: "payment_intent"
            },
            status:"open",
            status_transitions: {
              canceled_at: nil,
              paid_at: nil
            }
          }
        ],
        has_more: false,
        url: "/v1/invoice_payments"
      }
    ))

    assert_enqueued_jobs 1 do
      Pay::Stripe::Webhooks::PaymentActionRequired.new.call(@event)
    end
  end

  test "skips email if subscription is incomplete" do
    Pay::Stripe::Subscription.sync @event.data.object.subscription, object: fake_stripe_subscription(id: @event.data.object.subscription, customer: @event.data.object.customer, status: :incomplete)

    assert_no_enqueued_jobs do
      Pay::Stripe::Webhooks::PaymentActionRequired.new.call(@event)
    end
  end
end
