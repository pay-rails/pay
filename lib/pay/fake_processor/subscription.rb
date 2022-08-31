module Pay
  module FakeProcessor
    class Subscription
      attr_reader :pay_subscription

      delegate :active?,
        :canceled?,
        :on_grace_period?,
        :on_trial?,
        :ends_at,
        :owner,
        :processor_subscription,
        :processor_id,
        :prorate,
        :processor_plan,
        :quantity?,
        :quantity,
        to: :pay_subscription

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription(**options)
        pay_subscription
      end

      # With trial, sets end to trial end (mimicing Stripe)
      # Without trial, sets can ends_at to end of month
      def cancel(**options)
        if pay_subscription.on_trial?
          pay_subscription.update(ends_at: pay_subscription.trial_ends_at)
        else
          pay_subscription.update(ends_at: Time.current.end_of_month)
        end
      end

      def cancel_now!(**options)
        ends_at = Time.current
        pay_subscription.update(
          status: :canceled,
          trial_ends_at: (ends_at if pay_subscription.trial_ends_at?),
          ends_at: ends_at
        )
      end

      def paused?
        pay_subscription.status == "paused"
      end

      def pause
        pay_subscription.update(status: :paused, trial_ends_at: Time.current)
      end

      def resume
        unless on_grace_period? || paused?
          raise StandardError, "You can only resume subscriptions within their grace period."
        end
      end

      def swap(plan)
      end

      def change_quantity(quantity)
      end
    end
  end
end
