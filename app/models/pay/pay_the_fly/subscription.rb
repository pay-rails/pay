# frozen_string_literal: true

module Pay
  module PayTheFly
    class Subscription < Pay::Subscription
      # PayTheFly is a one-time payment processor.
      # This model exists to satisfy the Pay framework's STI requirements
      # but all subscription methods raise appropriate errors.

      def api_record(**options)
        raise Pay::Error, "PayTheFly does not support subscriptions"
      end

      def cancel(**options)
        raise Pay::Error, "PayTheFly does not support subscriptions"
      end

      def cancel_now!(**options)
        raise Pay::Error, "PayTheFly does not support subscriptions"
      end

      def change_quantity(quantity, **options)
        raise Pay::Error, "PayTheFly does not support subscriptions"
      end

      def on_grace_period?
        false
      end

      def paused?
        false
      end

      def pause(**options)
        raise Pay::Error, "PayTheFly does not support subscriptions"
      end

      def resumable?
        false
      end

      def resume
        raise Pay::Error, "PayTheFly does not support subscriptions"
      end

      def swap(plan, **options)
        raise Pay::Error, "PayTheFly does not support subscriptions"
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_pay_the_fly_subscription, Pay::PayTheFly::Subscription
