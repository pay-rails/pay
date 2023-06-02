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

      def self.sync(subscription_id, object: nil, name: Pay.default_product_name)
        # Passthrough is not return from this API, so we can't use that
        object ||= OpenStruct.new PaddlePay::Subscription::User.list({subscription_id: subscription_id}).try(:first)

        pay_customer = Pay::Customer.find_by(processor: :paddle, processor_id: object.user_id)

        # If passthrough exists (only on webhooks) we can use it to create the Pay::Customer
        if pay_customer.nil? && object.passthrough
          owner = Pay::Paddle.owner_from_passthrough(object.passthrough)
          pay_customer = owner&.set_payment_processor(:paddle, processor_id: object.user_id)
        end

        return unless pay_customer

        attributes = {
          paddle_cancel_url: object.cancel_url,
          paddle_update_url: object.update_url,
          processor_plan: object.plan_id || object.subscription_plan_id,
          quantity: object.quantity,
          status: object.state || object.status
        }

        # If paused or delete while on trial, set ends_at to match
        case attributes[:status]
        when "trialing"
          attributes[:trial_ends_at] = Time.zone.parse(object.next_bill_date)
          attributes[:ends_at] = nil
        when "paused", "deleted"
          attributes[:trial_ends_at] = nil
          attributes[:ends_at] = Time.zone.parse(object.next_bill_date)
        end

        # Update or create the subscription
        if (pay_subscription = pay_customer.subscriptions.find_by(processor_id: object.subscription_id))
          pay_subscription.with_lock do
            pay_subscription.update!(attributes)
          end
          pay_subscription
        else
          pay_customer.subscriptions.create!(attributes.merge(name: name, processor_id: object.subscription_id))
        end
      end

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription(**options)
        hash = PaddlePay::Subscription::User.list({subscription_id: processor_id}, options).try(:first)
        OpenStruct.new(hash)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
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
