module Pay
  module FakeProcessor
    class Subscription
      attr_reader :pay_subscription

      delegate :canceled?,
        :ends_at,
        :on_trial?,
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
      def cancel
        if pay_subscription.on_trial?
          pay_subscription.update(ends_at: pay_subscription.trial_ends_at)
        else
          pay_subscription.update(ends_at: Time.current.end_of_month)
        end
      end

      def cancel_now!
        pay_subscription.update(ends_at: Time.current, status: :canceled)
      end

      def on_grace_period?
        canceled? && Time.current < ends_at
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
    end
  end
end
