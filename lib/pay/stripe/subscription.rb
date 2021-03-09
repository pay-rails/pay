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
        :stripe_account,
        :trial_ends_at,
        to: :pay_subscription

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def cancel
        stripe_sub = ::Stripe::Subscription.update(processor_id, {cancel_at_period_end: true}, {stripe_account: stripe_account})
        pay_subscription.update(ends_at: (on_trial? ? trial_ends_at : Time.at(stripe_sub.current_period_end)))
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def cancel_now!
        ::Stripe::Subscription.delete(processor_id, {stripe_account: stripe_account})
        pay_subscription.update(ends_at: Time.current, status: :canceled)
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

        ::Stripe::Subscription.update(
          processor_id,
          {
            plan: processor_plan,
            trial_end: (on_trial? ? trial_ends_at.to_i : "now"),
            cancel_at_period_end: false
          },
          {stripe_account: stripe_account}
        )
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def swap(plan)
        ::Stripe::Subscription.update(
          processor_id,
          {
            cancel_at_period_end: false,
            plan: plan,
            proration_behavior: (prorate ? "create_prorations" : "none"),
            trial_end: (on_trial? ? trial_ends_at.to_i : "now"),
            quantity: quantity
          },
          {stripe_account: stripe_account}
        )
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end
    end
  end
end
