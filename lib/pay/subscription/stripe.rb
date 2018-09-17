module Pay
  module Subscription
    module Stripe
      def stripe_cancel
        subscription = processor_subscription
        subscription.cancel_at_period_end
        subscription.save

        new_ends_at  = on_trial? ? trial_ends_at : Time.at(subscription.current_period_end)
        update(ends_at: new_ends_at)
      end

      def stripe_cancel_now!
        subscription = processor_subscription.delete
        update(ends_at: Time.zone.now)
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
        subscription.trial_end = on_trial? ? trial_ends_at.to_i : 'now'
        subscription.quantity = quantity if quantity?
        subscription.save
      end
    end
  end
end
