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

      def cancel
        pay_subscription.update(ends_at: Time.current.end_of_month)
      end

      def cancel_now!
        pay_subscription.update(ends_at: Time.current, status: :canceled)
      end

      def on_grace_period?
        canceled? && Time.zone.now < ends_at
      end

      def paused?
        false
      end

      def pause
        raise NotImplementedError, "FakeProcessor does not support pausing subscriptions"
      end

      def resume
        unless on_grace_period?
          raise StandardError, "You can only resume subscriptions within their grace period."
        end

        pay_subscription.update(ends_at: nil, status: :active)
      end

      def swap(plan)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        pay_subscription.update(processor_plan: plan)
      end
    end
  end
end
