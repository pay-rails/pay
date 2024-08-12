module Pay
  module PaddleClassic
    class Subscription < Pay::Subscription
      def self.sync(subscription_id, object: nil, name: Pay.default_product_name)
        # Passthrough is not return from this API, so we can't use that
        object ||= PaddleClassic.client.users.list(subscription_id: subscription_id).data.try(:first)

        pay_customer = Pay::Customer.find_by(processor: :paddle_classic, processor_id: object.user_id)

        # If passthrough exists (only on webhooks) we can use it to create the Pay::Customer
        if pay_customer.nil? && object.passthrough
          owner = Pay::PaddleClassic.owner_from_passthrough(object.passthrough)
          pay_customer = owner&.set_payment_processor(:paddle_classic, processor_id: object.user_id)
        end

        return unless pay_customer

        attributes = {
          paddle_cancel_url: object.cancel_url,
          paddle_update_url: object.update_url,
          processor_plan: object.plan_id || object.subscription_plan_id,
          quantity: object.quantity || 1,
          status: object.state || object.status
        }

        case attributes[:status]
        when "trialing"
          attributes[:trial_ends_at] = Time.zone.parse(object.next_bill_date)
          attributes[:ends_at] = nil
        when "active", "past_due"
          attributes[:trial_ends_at] = nil
          attributes[:ends_at] = nil
        when "paused", "deleted"
          # If paused or delete while on trial, set ends_at to match
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

      def api_record(**options)
        PaddleClassic.client.users.list(subscription_id: processor_id).data.try(:first)
      rescue ::Paddle::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      # Paddle subscriptions are canceled immediately, however we still want to give the user access to the end of the period they paid for
      def cancel(**options)
        return if canceled?

        ends_at = if on_trial?
          trial_ends_at
        elsif paused?
          pause_starts_at
        else
          Time.parse(api_record.next_payment.date)
        end

        PaddleClassic.client.users.cancel(subscription_id: processor_id)
        update(
          status: (ends_at.future? ? :active : :canceled),
          ends_at: ends_at
        )

        # Remove payment methods since customer cannot be reused after cancelling
        Pay::PaymentMethod.where(customer_id: customer_id).destroy_all
      rescue ::Paddle::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      def cancel_now!(**options)
        return if canceled?

        PaddleClassic.client.users.cancel(subscription_id: processor_id)
        update(status: :canceled, ends_at: Time.current)

        # Remove payment methods since customer cannot be reused after cancelling
        Pay::PaymentMethod.where(customer_id: customer_id).destroy_all
      rescue ::Paddle::Error => e
        raise Pay::PaddleClassic::Error, e
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
        status == "paused"
      end

      def pause
        response = PaddleClassic.client.users.pause(subscription_id: processor_id)
        update(status: :paused, pause_starts_at: Time.zone.parse(response.dig(:next_payment, :date)))
      rescue ::Paddle::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      def resumable?
        paused?
      end

      def resume
        unless resumable?
          raise StandardError, "You can only resume paused subscriptions."
        end

        PaddleClassic.client.users.unpause(subscription_id: processor_id)
        update(ends_at: nil, status: :active, pause_starts_at: nil)
      rescue ::Paddle::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      def swap(plan, **options)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        attributes = {plan_id: plan, prorate: prorate}
        attributes[:quantity] = quantity if quantity?
        PaddleClassic.client.users.update(subscription_id: processor_id, **attributes)

        update(processor_plan: plan, ends_at: nil, status: :active)
      rescue ::Paddle::Error => e
        raise Pay::PaddleClassic::Error, e
      end

      # Retries the latest invoice for a Past Due subscription
      def retry_failed_payment
      end
    end
  end
end
