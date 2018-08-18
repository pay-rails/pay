module Pay
  module Subscription
    module Stripe
      def stripe_cancel
        subscription = processor_subscription.delete(at_period_end: true)
        update(ends_at: Time.at(subscription.current_period_end))
      end

      def stripe_cancel_now!
        subscription = processor_subscription.delete
        update(ends_at: Time.at(subscription.current_period_end))
      end

      def stripe_resume
        subscription = processor_subscription
        subscription.plan = processor_plan
        subscription.trial_end = on_trial? ? trial_ends_at.to_i : 'now'
        subscription.cancel_at_period_end = false
        subscription.save
      end

      def stripe_swap(plan)
        subscription = processor_subscription
        subscription.plan = plan
        subscription.prorate = prorate
        subscription.trial_end = on_trial? ? trial_ends_at : 'now'
        subscription.quantity = quantity if quantity?
        subscription.save
      end
    end
  end
end
