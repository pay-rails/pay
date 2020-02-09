module Pay
  module Stripe
    module Subscription
      def stripe?
        processor == "stripe"
      end

      def stripe_cancel
        subscription = processor_subscription
        subscription.cancel_at_period_end = true
        subscription.save

        new_ends_at = on_trial? ? trial_ends_at : Time.at(subscription.current_period_end)
        update(ends_at: new_ends_at, status: :canceled)
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      def stripe_cancel_now!
        processor_subscription.delete
        update(ends_at: Time.zone.now, status: :canceled)
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      def stripe_resume
        subscription = processor_subscription
        subscription.plan = processor_plan
        subscription.trial_end = on_trial? ? trial_ends_at.to_i : "now"
        subscription.cancel_at_period_end = false
        subscription.save
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      def stripe_swap(plan)
        subscription = processor_subscription
        subscription.cancel_at_period_end = false
        subscription.plan = plan
        subscription.prorate = prorate
        subscription.trial_end = on_trial? ? trial_ends_at.to_i : "now"
        subscription.quantity = quantity if quantity?
        subscription.save
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end
    end
  end
end
