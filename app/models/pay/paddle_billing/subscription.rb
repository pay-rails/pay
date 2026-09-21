module Pay
  module PaddleBilling
    class Subscription < Pay::Subscription
      extend Pay::Sync

      store_accessor :data, :paddle_update_url
      store_accessor :data, :paddle_cancel_url

      def self.sync_from_transaction(transaction_id)
        Pay.deprecator.warn "Pay::PaddleBilling::Subscription.sync_from_transaction is deprecated, use Pay::PaddleBilling.sync_transaction instead"
        Pay::PaddleBilling.sync_transaction(transaction_id)
      end

      def self.sync(subscription_id, object: nil, name: Pay.default_product_name)
        sync_with_retries do
          subscription = object || ::Paddle::Subscription.retrieve(id: subscription_id)
          return unless (pay_customer = find_pay_customer(subscription.customer_id))

          attributes = {
            current_period_end: subscription.current_billing_period&.ends_at,
            current_period_start: subscription.current_billing_period&.starts_at,
            ends_at: (subscription.canceled_at ? Time.parse(subscription.canceled_at) : nil),
            metadata: subscription.custom_data,
            paddle_cancel_url: subscription.management_urls&.cancel,
            paddle_update_url: subscription.management_urls&.update_payment_method,
            pause_starts_at: (subscription.paused_at ? Time.parse(subscription.paused_at) : nil),
            status: subscription.status
          }

          if subscription.items&.first
            item = subscription.items.first
            attributes[:processor_plan] = item.price.id
            attributes[:quantity] = item.quantity
          end

          case attributes[:status]
          when "canceled"
            # Remove payment methods since customer cannot be reused after cancelling
            pay_customer.payment_methods.destroy_all
          when "trialing"
            attributes[:trial_ends_at] = Time.parse(subscription.next_billed_at) if subscription.next_billed_at
          when "paused"
            attributes[:pause_starts_at] = Time.parse(subscription.paused_at) if subscription.paused_at
          when "active", "past_due"
            attributes[:trial_ends_at] = nil
            attributes[:pause_starts_at] = nil
            attributes[:ends_at] = nil
          end

          case subscription.scheduled_change&.action
          when "cancel"
            attributes[:ends_at] = Time.parse(subscription.scheduled_change.effective_at)
          when "pause"
            attributes[:pause_starts_at] = Time.parse(subscription.scheduled_change.effective_at)
          when "resume"
            attributes[:pause_resumes_at] = Time.parse(subscription.scheduled_change.effective_at)
          end

          # Update or create the subscription
          if (pay_subscription = find_by(customer: pay_customer, processor_id: subscription_id))
            pay_subscription.with_lock { pay_subscription.update!(attributes) }
            pay_subscription
          else
            create!(attributes.merge(customer: pay_customer, name: name, processor_id: subscription_id))
          end
        end
      end

      def api_record(**options)
        @api_record ||= ::Paddle::Subscription.retrieve(id: processor_id, **options)
      end

      # Get a transaction to update payment method
      def payment_method_transaction
        ::Paddle::Subscription.get_transaction(id: processor_id)
      end

      # If a subscription is paused, cancel immediately
      # Otherwise, cancel at period end
      def cancel(**options)
        return if canceled?

        response = ::Paddle::Subscription.cancel(
          id: processor_id,
          effective_from: options.fetch(:effective_from, paused? ? "immediately" : "next_billing_period")
        )
        update(
          status: response.status,
          ends_at: response.scheduled_change&.effective_at || Time.current
        )
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      def cancel_now!(**options)
        cancel(**options.merge(effective_from: "immediately"))
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      def change_quantity(quantity, **options)
        items = [{
          price_id: processor_plan,
          quantity: quantity
        }]

        ::Paddle::Subscription.update(
          id: processor_id,
          items: items,
          proration_billing_mode: options.delete(:proration_billing_mode) || "prorated_immediately"
        )
        update(quantity: quantity)
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      # A subscription could be set to cancel or pause in the future
      # It is considered on grace period until the cancel or pause time begins
      def on_grace_period?
        (canceled? && Time.current < ends_at) || (paused? && pause_starts_at? && Time.current < pause_starts_at)
      end

      def paused?
        status == "paused"
      end

      def pause
        response = ::Paddle::Subscription.pause(id: processor_id)
        update!(status: :paused, pause_starts_at: response.scheduled_change.effective_at)
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      def resumable?
        paused?
      end

      def resume
        unless resumable?
          raise Error, "You can only resume paused subscriptions."
        end

        # Paddle Billing API only allows "resuming" subscriptions when they are paused
        # So cancel the scheduled change if it is in the future
        if paused? && pause_starts_at? && Time.current < pause_starts_at
          ::Paddle::Subscription.update(id: processor_id, scheduled_change: nil)
        else
          ::Paddle::Subscription.resume(id: processor_id, effective_from: "immediately")
        end

        update(ends_at: nil, status: :active, pause_starts_at: nil)
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      def swap(plan, **options)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        items = [{
          price_id: plan,
          quantity: quantity || 1
        }]

        ::Paddle::Subscription.update(
          id: processor_id,
          items: items,
          proration_billing_mode: options.delete(:proration_billing_mode) || "prorated_immediately"
        )
        update(processor_plan: plan, ends_at: nil, status: :active)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_paddle_billing_subscription, Pay::PaddleBilling::Subscription
