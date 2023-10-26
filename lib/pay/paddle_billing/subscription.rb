module Pay
  module PaddleBilling
    class Subscription
      attr_reader :pay_subscription

      delegate :active?,
        :canceled?,
        :on_grace_period?,
        :on_trial?,
        :ends_at,
        :name,
        :owner,
        :pause_starts_at,
        :pause_starts_at?,
        :processor_id,
        :processor_plan,
        :processor_subscription,
        :prorate,
        :prorate?,
        :quantity,
        :quantity?,
        :trial_ends_at,
        to: :pay_subscription

      def self.sync_from_transaction(transaction_id)
        transaction = ::Paddle::Transaction.retrieve(id: transaction_id)
        sync(transaction.subscription_id) if transaction.subscription_id
      end

      def self.sync(subscription_id, object: nil)
        # Passthrough is not return from this API, so we can't use that
        object ||= ::Paddle::Subscription.retrieve(id: subscription_id)

        pay_customer = Pay::Customer.find_by(processor: :paddle_billing, processor_id: object.customer_id)
        return unless pay_customer

        attributes = {
          current_period_end: object.current_billing_period&.ends_at,
          current_period_start: object.current_billing_period&.starts_at,
          ends_at: (object.canceled_at ? Time.parse(object.canceled_at) : nil),
          metadata: object.custom_data,
          paddle_cancel_url: object.management_urls&.cancel,
          paddle_update_url: object.management_urls&.update_payment_method,
          pause_starts_at: (object.paused_at ? Time.parse(object.paused_at) : nil),
          status: object.status
        }

        if object.items&.first
          item = object.items.first
          attributes[:name] = item.price.description
          attributes[:processor_plan] = item.price.id
          attributes[:quantity] = item.quantity
        end

        case attributes[:status]
        when "canceled"
          # Remove payment methods since customer cannot be reused after cancelling
          Pay::PaymentMethod.where(customer_id: pay_subscription.customer_id).destroy_all
        when "trialing"
          attributes[:trial_ends_at] = Time.parse(object.next_billed_at)
        when "paused"
          attributes[:pause_starts_at] = Time.parse(object.paused_at)
        end

        case object.scheduled_change&.action
        when "cancel"
          attributes[:ends_at] = Time.parse(object.scheduled_change.effective_at)
        when "pause"
          attributes[:pause_starts_at] = Time.parse(object.scheduled_change.effective_at)
        when "resume"
          attributes[:pause_resumes_at] = Time.parse(object.scheduled_change.effective_at)
        end

        # Update or create the subscription
        if (pay_subscription = pay_customer.subscriptions.find_by(processor_id: subscription_id))
          pay_subscription.with_lock do
            pay_subscription.update!(attributes)
          end
          pay_subscription
        else
          pay_customer.subscriptions.create!(attributes.merge(name: name, processor_id: subscription_id))
        end
      end

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription
        ::Paddle::Subscription.retrieve(id: processor_id)
      end

      # Get a transaction to update payment method
      def payment_method_transaction
        ::Paddle::Subscription.get_transaction(id: processor_id)
      end

      def cancel(**options)
        return if canceled?

        response = ::Paddle::Subscription.cancel(
          id: processor_id,
          effective_from: options.fetch(:effective_from, "next_billing_period")
        )
        pay_subscription.update(
          status: :canceled,
          ends_at: response.scheduled_change.effective_at
        )
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      def cancel_now!(**options)
        cancel(options.merge(effective_from: "immediately"))
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      def change_quantity(quantity, **options)
        items = [{
          price_id: processor_plan,
          quantity: quantity
        }]

        ::Paddle::Subscription.update(id: processor_id, items: items, proration_billing_mode: "prorated_immediately")
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      # A subscription could be set to cancel or pause in the future
      # It is considered on grace period until the cancel or pause time begins
      def on_grace_period?
        (canceled? && Time.current < ends_at) || (paused? && pause_starts_at? && Time.current < pause_starts_at)
      end

      def paused?
        pay_subscription.status == "paused"
      end

      def pause
        response = ::Paddle::Subscription.pause(id: processor_id)
        pay_subscription.update!(status: :paused, pause_starts_at: response.scheduled_change.effective_at)
      rescue ::Paddle::Error => e
        raise Pay::Paddle::Error, e
      end

      def resume
        unless paused?
          raise StandardError, "You can only resume paused subscriptions."
        end

        # Paddle Billing API only allows "resuming" subscriptions when they are paused
        # So cancel the scheduled change if it is in the future
        if paused? && pause_starts_at? && Time.current < pause_starts_at
          ::Paddle::Subscription.update(id: processor_id, scheduled_change: nil)
        else
          ::Paddle::Subscription.resume(id: processor_id, effective_from: "immediately")
        end

        pay_subscription.update(status: :active, pause_starts_at: nil)
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      def swap(plan, **options)
        items = [{
          price_id: plan,
          quantity: quantity || 1
        }]

        ::Paddle::Subscription.update(id: processor_id, items: items, proration_billing_mode: "prorated_immediately")
        pay_subscription.update(processor_plan: plan, ends_at: nil, status: :active)
      end

      # Retries the latest invoice for a Past Due subscription
      def retry_failed_payment
      end
    end
  end
end
