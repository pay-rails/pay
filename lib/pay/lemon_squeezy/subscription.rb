module Pay
  module LemonSqueezy
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

      def self.sync(subscription_id, object: nil, name: Pay.default_product_name)
        pay_customer = Pay::Customer.find_by(processor: :paddle, processor_id: object.customer_id)

        # If passthrough exists (only on webhooks) we can use it to create the Pay::Customer
        if pay_customer.nil? && object.passthrough
          owner = Pay::LemonSqueezy.owner_from_passthrough(object.passthrough)
          pay_customer = owner&.set_payment_processor(:lemon_squeezy, processor_id: object.customer_id)
        end

        return unless pay_customer

        attributes = {
          # This expires so should be grabbed when the customer wants it
          # lemon_squeezy_update_url: object.urls&.update_payment_method,
          processor_plan: object.product_id,
          quantity: 1,
          status: object.status
        }

        # If paused or delete while on trial, set ends_at to match
        case attributes[:status]
        when "trialing"
          attributes[:trial_ends_at] = Time.zone.parse(object.trial_ends_at)
          attributes[:ends_at] = nil
        when "paused", "deleted"
          attributes[:trial_ends_at] = nil
          attributes[:ends_at] = Time.zone.parse(object.ends_at)
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

      def subscription(**options)
        Pay::LemonSqueezy.client.subscriptions.get(id: processor_id)
        # hash = PaddlePay::Subscription::User.list({subscription_id: processor_id}, options).try(:first)
        # OpenStruct.new(hash)
        # rescue ::PaddlePay::PaddlePayError => e
        #   raise Pay::Paddle::Error, e
      end

      def cancel(**options)
        ends_at = if on_trial?
          trial_ends_at
        elsif paused?
          pause_starts_at
        else
          processor_subscription.next_payment&.fetch(:date) || Time.current
        end

        PaddlePay::Subscription::User.cancel(processor_id)
        pay_subscription.update(status: :canceled, ends_at: ends_at)

        # Remove payment methods since customer cannot be reused after cancelling
        Pay::PaymentMethod.where(customer_id: pay_subscription.customer_id).destroy_all
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def cancel_now!(**options)
        PaddlePay::Subscription::User.cancel(processor_id)
        pay_subscription.update(status: :canceled, ends_at: Time.current)

        # Remove payment methods since customer cannot be reused after cancelling
        Pay::PaymentMethod.where(customer_id: pay_subscription.customer_id).destroy_all
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def change_quantity(quantity, **options)
        raise NotImplementedError, "Paddle does not support setting quantity on subscriptions"
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
        attributes = {pause: true}
        response = PaddlePay::Subscription::User.update(processor_id, attributes)
        pay_subscription.update(status: :paused, pause_starts_at: Time.zone.parse(response.dig(:next_payment, :date)))
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def resume
        unless paused?
          raise StandardError, "You can only resume paused subscriptions."
        end

        attributes = {pause: false}
        PaddlePay::Subscription::User.update(processor_id, attributes)
        pay_subscription.update(status: :active, pause_starts_at: nil)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def swap(plan, **options)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        attributes = {plan_id: plan, prorate: prorate}
        attributes[:quantity] = quantity if quantity?
        PaddlePay::Subscription::User.update(processor_id, attributes)

        pay_subscription.update(processor_plan: plan, ends_at: nil, status: :active)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      # Retries the latest invoice for a Past Due subscription
      def retry_failed_payment
      end
    end
  end
end
