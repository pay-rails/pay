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

      def self.sync(subscription_id, subscription: nil, name: Pay.default_product_name)
        # Skip loading the latest subscription details from the API if we already have it
        subscription ||= ::Stripe::Subscription.retrieve(id: subscription_id, expand: ["pending_setup_intent", "latest_invoice.payment_intent"])

        owner = Pay.find_billable(processor: :stripe, processor_id: subscription.customer)
        return if owner.nil?

        attributes = {
          application_fee_percent: subscription.application_fee_percent,
          processor_plan: subscription.plan.id,
          quantity: subscription.quantity,
          name: name,
          status: subscription.status,
          trial_ends_at: (subscription.trial_end ? Time.at(subscription.trial_end) : nil)
        }

        # Subscriptions cancelling in the future
        attributes[:ends_at] = Time.at(subscription.current_period_end) if subscription.cancel_at_period_end

        # Fully cancelled subscription
        attributes[:ends_at] = Time.at(subscription.ended_at) if subscription.ended_at

        # Update or create the subscription
        pay_subscription = owner.subscriptions.find_or_initialize_by(processor: :stripe, processor_id: subscription.id)
        pay_subscription.update(attributes)
        pay_subscription
      end

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription(**options)
        ::Stripe::Subscription.retrieve(options.merge(id: processor_id))
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

      def change_quantity(quantity)
        ::Stripe::Subscription.update(processor_id, quantity: quantity)
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
