module Pay
  module LemonSqueezy
    class Subscription < Pay::Subscription
      def self.sync(subscription_id, object: nil, name: Pay.default_product_name)
        object ||= ::LemonSqueezy::Subscription.retrieve(id: subscription_id)

        pay_customer = Pay::Customer.find_by(processor: :lemon_squeezy, processor_id: object.customer_id)
        return unless pay_customer

        attributes = {
          current_period_end: object.renews_at,
          ends_at: (object.ends_at ? Time.parse(object..ends_at) : nil),
          pause_starts_at: (object.pause&.resumes_at ? Time.parse(object.pause.resumes_at) : nil),
          status: object.status,
          processor_plan: object.first_subscription_item.price_id,
          quantity: object.first_subscription_item.quantity,
          created_at: (object.created_at ? Time.parse(object.created_at) : nil),
          updated_at: (object.updated_at ? Time.parse(object.updated_at) : nil)
        }

        case attributes[:status]
        when "cancelled"
          # Remove payment methods since customer cannot be reused after cancelling
          Pay::PaymentMethod.where(customer_id: object.customer_id).destroy_all
        when "on_trial"
          attributes[:trial_ends_at] = Time.parse(object.trial_ends_at)
        when "paused"
          # attributes[:pause_starts_at] = Time.parse(object.paused_at)
        when "active", "past_due"
          attributes[:trial_ends_at] = nil
          attributes[:pause_starts_at] = nil
          attributes[:ends_at] = nil
        end

        # Update or create the subscription
        if (pay_subscription = pay_customer.subscriptions.find_by(processor_id: object.id))
          pay_subscription.with_lock do
            pay_subscription.update!(attributes)
          end
          pay_subscription
        else
          pay_customer.subscriptions.create!(attributes.merge(name: name, processor_id: object.id))
        end
      end

      def api_record(**options)
        @api_record ||= ::LemonSqueezy::Subscription.retrieve(id: processor_id)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      def portal_url
        api_record.urls.customer_portal
      end

      def update_url
        api_record.urls.update_payment_method
      end

      def cancel(**options)
        return if canceled?
        response = ::LemonSqueezy::Subscription.cancel(id: processor_id)
        update(status: response.status, ends_at: response.ends_at)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      def cancel_now!(**options)
        raise Pay::Error, "Lemon Squeezy does not support cancelling immediately through the API."
      end

      def change_quantity(quantity, **options)
        subscription_item = api_record.first_subscription_item
        ::LemonSqueezy::SubscriptionItem.update(id: subscription_item.id, quantity: quantity)
        update(quantity: quantity)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      # A subscription could be set to cancel or pause in the future
      # It is considered on grace period until the cancel or pause time begins
      def on_grace_period?
        (canceled? && Time.current < ends_at) || (paused? && pause_starts_at? && Time.current < pause_starts_at)
      end

      def paused?
        status == "paused"
      end

      def pause(**options)
        response = ::LemonSqueezy::Subscription.pause(id: processor_id, **options)
        update!(status: :paused, pause_starts_at: response.pause&.resumes_at)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      def resumable?
        paused? || canceled?
      end

      def resume
        unless resumable?
          raise StandardError, "You can only resume paused or cancelled subscriptions"
        end

        if paused? && pause_starts_at? && Time.current < pause_starts_at
          ::LemonSqueezy::Subscription.unpause(id: processor_id)
        else
          ::LemonSqueezy::Subscription.uncancel(id: processor_id)
        end

        update(ends_at: nil, status: :active, pause_starts_at: nil)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      # Lemon Squeezy requires both the Product ID and Variant ID.
      # The Variant ID will be saved as the processor_plan
      def swap(plan, **options)
        raise StandardError, "A plan_id is required to swap a subscription" unless plan
        raise StandardError, "A variant_id is required to swap a subscription" unless options[:variant_id]

        ::LemonSqueezy::Subscription.change_plan id: processor_id, plan_id: plan, variant_id: options[:variant_id]

        update(processor_plan: options[:variant_id], ends_at: nil, status: :active)
      end
    end
  end
end
