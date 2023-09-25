module Pay
  module Lago
    class Subscription
      STATUS_MAP = {
        "pending" => "active",
        "terminated" => "canceled"
      }
      attr_reader :pay_subscription

      delegate :active?,
        :canceled?,
        :on_grace_period?,
        :on_trial?,
        :ends_at,
        :ends_at?,
        :owner,
        :processor_subscription,
        :processor_id,
        :prorate,
        :processor_plan,
        :quantity?,
        :quantity,
        to: :pay_subscription

      def self.sync(customer_id, subscription_id, object: nil, try: 0, retries: 1)
        object ||= get_subscription(customer_id, subscription_id)

        pay_customer = Pay::Customer.find_by(processor: :lago, processor_id: customer_id)
        if pay_customer.blank?
          Rails.logger.debug "Pay::Customer #{object.customer} is not in the database while syncing Lago Subscription #{object.lago_id}"
          return
        end

        attrs = {
          name: object.name.present? ? object.name : Pay.default_plan_name,
          processor_id: object.external_id,
          processor_plan: object.plan_code,
          ends_at: object.cancelled_at || object.terminated_at,
          quantity: 1,
          status: STATUS_MAP.fetch(object.status, object.status),
          data: Lago.openstruct_to_h(object)
        }

        # Update or create the charge
        if (pay_subscription = pay_customer.subscriptions.find_by(processor_id: subscription_id))
          pay_subscription.with_lock do
            pay_subscription.update!(attrs)
          end
          pay_subscription
        else
          pay_customer.subscriptions.create!(attrs)
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      def self.get_subscription(customer_id, external_id)
        result = Lago.client.subscriptions.get_all(external_customer_id: customer_id, per_page: 9223372036854775807)
        result.subscriptions.each { |sub| return sub if sub.external_id == external_id }
        raise Pay::Lago::Error.new("No subscription could be found.")
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription
        @lago_subscription ||= self.class.get_subscription(pay_subscription.customer.processor_id, processor_id)
      end

      def cancel(**options)
        customer_id = subscription.external_customer_id
        response = Lago.client.subscriptions.destroy(URI.encode_www_form_component(processor_id), options: options)
        self.class.sync(customer_id, processor_id, object: response)
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end

      def cancel_now!(**options)
        cancel(options)
      end

      def change_quantity(_quantity, **_options)
        raise Pay::Lago::Error.new("Lago subscriptions do not implement quantity.")
      end

      def on_grace_period?
        false
      end

      def paused?
        false
      end

      def changing_plan?
        return false unless subscription.downgrade_plan_date
        subscription.downgrade_plan_date > Time.now
      end

      def pause
        raise Pay::Lago::Error.new("Lago subscriptions cannot be paused.")
      end

      def resume
        raise Pay::Lago::Error.new("Lago subscriptions cannot be paused.")
      end

      def swap(plan, **options)
        customer_id = subscription.external_customer_id
        attributes = options.merge(
          external_customer_id: customer_id,
          external_id: processor_id, plan_code: plan
        )
        new_subscription = Lago.client.subscriptions.create(attributes)
        self.class.sync(customer_id, processor_id, object: new_subscription)
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end

      # Retries the latest invoice for a Past Due subscription
      def retry_failed_payment
        raise Pay::Lago::Error.new("Lago subscriptions cannot be retried.")
      end
    end
  end
end
