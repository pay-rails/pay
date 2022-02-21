module Pay
  module Stripe
    class Subscription
      attr_reader :pay_subscription

      delegate :active?,
        :canceled?,
        :ends_at,
        :name,
        :on_trial?,
        :processor_id,
        :processor_plan,
        :processor_subscription,
        :prorate,
        :prorate?,
        :quantity,
        :quantity?,
        :stripe_account,
        :trial_ends_at,
        to: :pay_subscription

      def self.sync(subscription_id, object: nil, name: Pay.default_product_name, stripe_account: nil, try: 0, retries: 1)
        # Skip loading the latest subscription details from the API if we already have it
        object ||= ::Stripe::Subscription.retrieve(
          {
            id: subscription_id,
            expand: [
              "pending_setup_intent",
              "latest_invoice.payment_intent",
              "latest_invoice.charge.invoice"
            ]
          }, {stripe_account: stripe_account}.compact
        )

        pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)
        return unless pay_customer

        attributes = {
          application_fee_percent: object.application_fee_percent,
          processor_plan: object.plan&.id,
          quantity: object.quantity,
          status: object.status,
          stripe_account: pay_customer.stripe_account,
          trial_ends_at: (object.trial_end ? Time.at(object.trial_end) : nil),
          metadata: object.metadata
        }

        attributes[:ends_at] = if object.ended_at
          # Fully cancelled subscription
          Time.at(object.ended_at)
        elsif object.cancel_at
          # subscription cancelling in the future
          Time.at(object.cancel_at)
        elsif object.cancel_at_period_end
          # Subscriptions cancelling in the future
          Time.at(object.current_period_end)
        end

        # Update or create the subscription
        pay_subscription = pay_customer.subscriptions.find_by(processor_id: object.id)
        if pay_subscription
          si_attributes = sync_subscription_items_attributes(pay_subscription, object.items.data)
          pay_subscription.with_lock do
            pay_subscription.update!(attributes.merge(subscription_items_attributes: si_attributes))
          end
        else
          pay_subscription = pay_customer.subscriptions.create!(attributes.merge(name: name, processor_id: object.id))
          si_attributes = sync_subscription_items_attributes(pay_subscription, object.items.data)
          pay_subscription.update(subscription_items_attributes: si_attributes)
        end

        # Sync the latest charge if we already have it loaded (like during subscrbe), otherwise, let webhooks take care of creating it
        if (charge = object.try(:latest_invoice).try(:charge)) && charge.try(:status) == "succeeded"
          Pay::Stripe::Charge.sync(charge.id, object: charge)
        end

        pay_subscription
      rescue ActiveRecord::RecordInvalid
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      def self.sync_subscription_items_attributes(subscription, items_data)
        return subscription_items_attributes(items_data) if subscription.subscription_items.empty?

        # Destroy all existing subscription items
        items_to_destroy = subscription.subscription_items.map do |subscription_item|
          {id: subscription_item.id, _destroy: true}
        end

        # Rebuild subscription item records based on new items data
        subscription_items_attributes(items_data) + items_to_destroy
      end

      def self.subscription_items_attributes(items_data)
        items_data.map do |subscription_item|
          {
            processor_id: subscription_item.id,
            processor_price: subscription_item.price.id,
            quantity: subscription_item.quantity
          }
        end
      end

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription(**options)
        options[:id] = processor_id
        options[:expand] ||= ["pending_setup_intent", "latest_invoice.payment_intent", "latest_invoice.charge.invoice"]
        ::Stripe::Subscription.retrieve(options, {stripe_account: stripe_account}.compact)
      end

      def cancel
        stripe_sub = ::Stripe::Subscription.update(processor_id, {cancel_at_period_end: true}, stripe_options)
        pay_subscription.update(ends_at: (on_trial? ? trial_ends_at : Time.at(stripe_sub.current_period_end)))
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def cancel_now!
        ::Stripe::Subscription.delete(processor_id, {}, stripe_options)
        pay_subscription.update(ends_at: Time.current, status: :canceled)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def change_quantity(quantity)
        ::Stripe::Subscription.update(processor_id, {quantity: quantity}, stripe_options)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def on_grace_period?
        canceled? && Time.current < ends_at
      end

      def paused?
        false
      end

      def pause
        raise NotImplementedError, "Stripe does not support pausing subscriptions"
      end

      def resume
        unless on_grace_period?
          raise StandardError, "You can only resume subscriptions within their grace period."
        end

        ::Stripe::Subscription.update(
          processor_id,
          {
            plan: processor_plan,
            trial_end: (on_trial? ? trial_ends_at.to_i : "now"),
            cancel_at_period_end: false
          },
          stripe_options
        )
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def swap(plan)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        ::Stripe::Subscription.update(
          processor_id,
          {
            cancel_at_period_end: false,
            plan: plan,
            proration_behavior: (prorate ? "create_prorations" : "none"),
            trial_end: (on_trial? ? trial_ends_at.to_i : "now"),
            quantity: quantity
          },
          stripe_options
        )
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: stripe_account}.compact
      end
    end
  end
end
