module Pay
  module LemonSqueezy
    class Subscription < Pay::Subscription
      extend Pay::Sync

      # Lemon Squeezy statuses that Pay spells differently
      STATUSES = {"on_trial" => "trialing", "cancelled" => "canceled"}.freeze

      def self.sync(subscription_id, object: nil, name: Pay.default_product_name)
        sync_with_retries do
          subscription = object || ::LemonSqueezy::Subscription.retrieve(id: subscription_id)
          return unless (pay_customer = find_pay_customer(subscription.customer_id))

          attributes = {
            current_period_end: subscription.renews_at,
            ends_at: (subscription.ends_at ? Time.parse(subscription.ends_at) : nil),
            pause_resumes_at: (subscription.pause&.resumes_at ? Time.parse(subscription.pause.resumes_at) : nil),
            status: STATUSES.fetch(subscription.status, subscription.status),
            processor_plan: subscription.first_subscription_item.price_id,
            quantity: subscription.first_subscription_item.quantity,
            created_at: (subscription.created_at ? Time.parse(subscription.created_at) : nil),
            updated_at: (subscription.updated_at ? Time.parse(subscription.updated_at) : nil)
          }

          case attributes[:status]
          when "canceled"
            # Remove payment methods since customer cannot be reused after cancelling
            pay_customer.payment_methods.destroy_all
          when "trialing"
            attributes[:trial_ends_at] = Time.parse(subscription.trial_ends_at)
          when "active", "past_due"
            attributes[:trial_ends_at] = nil
            attributes[:pause_resumes_at] = nil
            attributes[:ends_at] = nil
          end

          # Update or create the subscription
          if (pay_subscription = find_by(customer: pay_customer, processor_id: subscription.id))
            pay_subscription.with_lock { pay_subscription.update!(attributes) }
            pay_subscription
          else
            create!(attributes.merge(customer: pay_customer, name: name, processor_id: subscription.id))
          end
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
        raise NotImplementedError, "Lemon Squeezy does not support cancelling immediately through the API"
      end

      def change_quantity(quantity, **options)
        subscription_item = api_record.first_subscription_item
        ::LemonSqueezy::SubscriptionItem.update(id: subscription_item.id, quantity: quantity)
        update(quantity: quantity)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      def paused?
        status == "paused"
      end

      def pause(**options)
        response = ::LemonSqueezy::Subscription.pause(id: processor_id, **options)
        update!(status: :paused, pause_resumes_at: response.pause&.resumes_at)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      def resumable?
        paused? || canceled?
      end

      def resume
        unless resumable?
          raise Error, "You can only resume paused or cancelled subscriptions"
        end

        if paused?
          ::LemonSqueezy::Subscription.unpause(id: processor_id)
        else
          ::LemonSqueezy::Subscription.uncancel(id: processor_id)
        end

        update(ends_at: nil, status: :active, pause_resumes_at: nil)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      # Lemon Squeezy requires both the Product ID and Variant ID.
      # The Variant ID will be saved as the processor_plan
      def swap(plan, **options)
        raise Error, "A plan_id is required to swap a subscription" unless plan
        raise Error, "A variant_id is required to swap a subscription" unless options[:variant_id]

        ::LemonSqueezy::Subscription.change_plan id: processor_id, plan_id: plan, variant_id: options[:variant_id]

        update(processor_plan: options[:variant_id], ends_at: nil, status: :active)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_lemon_squeezy_subscription, Pay::LemonSqueezy::Subscription
