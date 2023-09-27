module Pay
  module Paddle
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

      def self.sync(subscription_id, object: nil)
        # Passthrough is not return from this API, so we can't use that
        object ||= ::Paddle::Subscription.retrieve(id: subscription_id)

        pay_customer = Pay::Customer.find_by(processor: :paddle, processor_id: object.customer_id)

        # If passthrough exists (only on webhooks) we can use it to create the Pay::Customer
        if pay_customer.nil? && object.custom_data
          owner = Pay::Paddle.owner_from_passthrough(object.custom_data.passthrough)
          pay_customer = owner&.set_payment_processor(:paddle, processor_id: object.customer_id)
        end

        return unless pay_customer

        attributes = {}

        attributes[:status] = object.status

        if object.items&.first
          item = object.items.first
          attributes[:name] = item.price.description
          attributes[:processor_plan] = item.price.id
          attributes[:quantity] = item.quantity
        end

        if object.management_urls
          attributes[:paddle_cancel_url] = object.management_urls.cancel
          attributes[:paddle_update_url] = object.management_urls.update_payment_method
        end

        # If paused or delete while on trial, set ends_at to match
        case attributes[:status]
        when "trialing"
          attributes[:trial_ends_at] = Time.zone.parse(object.next_billed_at)
          attributes[:ends_at] = nil
        when "paused", "deleted"
          attributes[:trial_ends_at] = nil
          attributes[:ends_at] = Time.zone.parse(object.next_billed_at)
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

      def cancel(**options)
        if on_trial?
          trial_ends_at
        elsif paused?
          pause_starts_at
        else
          processor_subscription.next_payment&.fetch(:date) || Time.current
        end

        response = ::Paddle::Subscription.cancel(id: processor_id, effective_from: "next_billing_period")

        pay_subscription.update(status: :canceled, ends_at: response.scheduled_change.effective_at)

        # Remove payment methods since customer cannot be reused after cancelling
        Pay::PaymentMethod.where(customer_id: pay_subscription.customer_id).destroy_all
      rescue ::Paddle::Error => e
        raise Pay::Paddle::Error, e
      end

      def cancel_now!(**options)
      end

      def change_quantity(quantity, **options)
        items = [{
          price_id: processor_plan,
          quantity: quantity
        }]

        ::Paddle::Subscription.update(id: processor_id, items: items, proration_billing_mode: "prorated_immediately")
      rescue ::Paddle::Error => e
        raise Pay::Paddle::Error, e
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
        raise Pay::Paddle::Error, e
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
