module Pay
  module FakeProcessor
    class Subscription < Pay::Subscription
      def self.sync(processor_id, **options)
        # Bypass sync operation for FakeProcessor
      end

      def api_record(**options)
        self
      end

      # With trial, sets end to trial end (mimicking Stripe)
      # Without trial, sets can ends_at to end of month
      def cancel(**options)
        return if canceled?
        update(ends_at: (on_trial? ? trial_ends_at : Time.current.end_of_month))
      end

      def cancel_now!(**options)
        return if canceled?

        ends_at = Time.current
        update(
          status: :canceled,
          trial_ends_at: (ends_at if trial_ends_at?),
          ends_at: ends_at
        )
      end

      def paused?
        status == "paused"
      end

      def pause
        update(status: :paused, trial_ends_at: Time.current)
      end

      def resumable?
        if data&.has_key?("resumable")
          data["resumable"]
        else
          on_grace_period? || paused?
        end
      end

      def resume
        unless resumable?
          raise Error, "You can only resume subscriptions within their grace period."
        end

        update(status: :active, trial_ends_at: nil, ends_at: nil)
      end

      def swap(plan, **options)
        update(processor_plan: plan, ends_at: nil, status: :active)
      end

      def change_quantity(quantity, **options)
        update(quantity: quantity)
      end

      # Retries the latest invoice for a Past Due subscription
      def retry_failed_payment
        update(status: :active)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_fake_processor_subscription, Pay::FakeProcessor::Subscription
