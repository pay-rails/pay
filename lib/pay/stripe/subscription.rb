module Pay
  module Stripe
    class Subscription
      attr_reader :pay_subscription

      delegate :active?,
        :canceled?,
        :ends_at,
        :name,
        :on_trial?,
        :owner,
        :processor_id,
        :processor_plan,
        :processor_subscription,
        :prorate,
        :prorate?,
        :quantity,
        :quantity?,
        :trial_ends_at,
        to: :pay_subscription

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def cancel
        subscription = processor_subscription
        subscription.cancel_at_period_end = true
        subscription.save

        new_ends_at = on_trial? ? trial_ends_at : Time.at(subscription.current_period_end)
        pay_subscription.update(ends_at: new_ends_at)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def cancel_now!
        processor_subscription.delete
        pay_subscription.update(ends_at: Time.zone.now, status: :canceled)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def on_grace_period?
        canceled? && Time.zone.now < ends_at
      end

      def paused?
        false
      end

      def pause
        raise NotImplementedError, "Stripe does not support pausing subscriptions"
      end

      def resume
        unless on_grace_period?
          raise StandardError, "You can only resume subscriptions within their grace period."
        end

        subscription = processor_subscription
        subscription.plan = processor_plan
        subscription.trial_end = on_trial? ? trial_ends_at.to_i : "now"
        subscription.cancel_at_period_end = false
        subscription.save
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def swap(plan)
        subscription = processor_subscription
        subscription.cancel_at_period_end = false
        subscription.plan = plan
        subscription.proration_behavior = (prorate ? "create_prorations" : "none")
        subscription.trial_end = on_trial? ? trial_ends_at.to_i : "now"
        subscription.quantity = quantity if quantity?
        subscription.save
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end
    end
  end
end
