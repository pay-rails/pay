require "test_helper"

class Pay::Stripe::Webhooks::PaymentFailedTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("invoice.payment_failed")
    @subscription_id = @event.data.object.parent.subscription_details.subscription
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: @event.data.object.customer)
  end

  test "customer should receive payment failed email if setting is enabled" do
    create_stripe_subscription(processor_id: @subscription_id)

    Pay.emails.stub(:payment_failed, true) do
      assert_emails 1 do
        mail = Pay::Stripe::Webhooks::PaymentFailed.new.call(@event)
        assert_equal I18n.t("pay.user_mailer.payment_failed.subject", application: Pay.application_name), mail.subject
      end
    end
  end

  test "skips email if setting is disabled" do
    create_stripe_subscription(processor_id: @subscription_id)

    Pay.emails.stub(:payment_failed, false) do
      assert_no_emails do
        Pay::Stripe::Webhooks::PaymentFailed.new.call(@event)
      end
    end
  end

  test "skips email if subscription is incomplete" do
    create_stripe_subscription(processor_id: @subscription_id, status: "incomplete")

    assert_no_emails do
      Pay::Stripe::Webhooks::PaymentFailed.new.call(@event)
    end
  end
end
