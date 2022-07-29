module Pay
  module Stripe
    class Subscription
      attr_accessor :stripe_subscription
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
        :subscription_items,
        :trial_ends_at,
        :pause_behavior,
        :pause_resumes_at,
        to: :pay_subscription

      def self.sync(subscription_id, object: nil, name: nil, stripe_account: nil, try: 0, retries: 1)
        # Skip loading the latest subscription details from the API if we already have it
        object ||= ::Stripe::Subscription.retrieve({id: subscription_id}.merge(expand_options), {stripe_account: stripe_account}.compact)

        pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)
        return unless pay_customer

        attributes = {
          application_fee_percent: object.application_fee_percent,
          processor_plan: object.items.first.price.id,
          quantity: object.items.first.try(:quantity) || 0,
          status: object.status,
          stripe_account: pay_customer.stripe_account,
          metadata: object.metadata,
          subscription_items: [],
          metered: false,
          pause_behavior: object.pause_collection&.behavior,
          pause_resumes_at: (object.pause_collection&.resumes_at ? Time.at(object.pause_collection&.resumes_at) : nil)
        }

        # Subscriptions that have ended should have their trial ended at the same time
        if object.trial_end
          attributes[:trial_ends_at] = Time.at(object.ended_at || object.trial_end)
        end

        # Record subscription items to db
        object.items.auto_paging_each do |subscription_item|
          if !attributes[:metered] && (subscription_item.to_hash.dig(:price, :recurring, :usage_type) == "metered")
            attributes[:metered] = true
          end

          attributes[:subscription_items] << subscription_item.to_hash.slice(:id, :price, :metadata, :quantity)
        end

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
          pay_subscription.with_lock { pay_subscription.update!(attributes) }
        else
          # Allow setting the subscription name in metadata, otherwise use the default
          name ||= object.metadata["pay_name"] || Pay.default_product_name

          pay_subscription = pay_customer.subscriptions.create!(attributes.merge(name: name, processor_id: object.id))
        end

        # Cache the Stripe subscription on the Pay::Subscription that we return
        pay_subscription.stripe_subscription = object

        # Sync the latest charge if we already have it loaded (like during subscrbe), otherwise, let webhooks take care of creating it
        if (charge = object.try(:latest_invoice).try(:charge)) && charge.try(:status) == "succeeded"
          Pay::Stripe::Charge.sync(charge.id, stripe_account: pay_subscription.stripe_account)
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

      # Common expand options for all requests that create, retrieve, or update a Stripe Subscription
      def self.expand_options
        {
          expand: [
            "pending_setup_intent",
            "latest_invoice.payment_intent",
            "latest_invoice.charge",
            "latest_invoice.total_discount_amounts.discount",
            "latest_invoice.total_tax_amounts.tax_rate"
          ]
        }
      end

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription(**options)
        options[:id] = processor_id
        @stripe_subscription ||= ::Stripe::Subscription.retrieve(options.merge(expand_options), {stripe_account: stripe_account}.compact)
      end

      def reload!
        @stripe_subscription = nil
      end

      # Returns a SetupIntent or PaymentIntent client secret for the subscription
      def client_secret
        stripe_sub = subscription
        stripe_sub&.pending_setup_intent&.client_secret || stripe_sub&.latest_invoice&.payment_intent&.client_secret
      end

      def cancel(**options)
        @stripe_subscription = ::Stripe::Subscription.update(processor_id, {cancel_at_period_end: true}.merge(expand_options), stripe_options)
        pay_subscription.update(ends_at: (on_trial? ? trial_ends_at : Time.at(@stripe_subscription.current_period_end)))
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Cancels a subscription immediately
      #
      # cancel_now!(prorate: true)
      # cancel_now!(invoice_now: true)
      def cancel_now!(**options)
        @stripe_subscription = ::Stripe::Subscription.delete(processor_id, options.merge(expand_options), stripe_options)
        pay_subscription.update(ends_at: Time.current, status: :canceled)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # This updates a SubscriptionItem's quantity in Stripe
      #
      # For a subscription with a single item, we can update the subscription directly if no SubscriptionItem ID is available
      # Otherwise a SubscriptionItem ID is required so Stripe knows which entry to update
      def change_quantity(quantity, **options)
        subscription_item_id = options.fetch(:subscription_item_id, subscription_items.first["id"])
        if subscription_item_id
          ::Stripe::SubscriptionItem.update(subscription_item_id, options.merge(quantity: quantity), stripe_options)
          @stripe_subscription = nil
        else
          @stripe_subscription = ::Stripe::Subscription.update(processor_id, options.merge(quantity: quantity).merge(expand_options), stripe_options)
        end
        true
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def on_grace_period?
        canceled? && Time.current < ends_at
      end

      def paused?
        pause_behavior.present?
      end

      # Pauses a Stripe subscription
      #
      # pause(behavior: "mark_uncollectible")
      # pause(behavior: "keep_as_draft")
      # pause(behavior: "void")
      # pause(behavior: "mark_uncollectible", resumes_at: 1.month.from_now)
      def pause(**options)
        attributes = {pause_collection: options.reverse_merge(behavior: "mark_uncollectible")}
        @stripe_subscription = ::Stripe::Subscription.update(processor_id, attributes.merge(expand_options), stripe_options)
        pay_subscription.update(
          pause_behavior: @stripe_subscription.pause_collection&.behavior,
          pause_resumes_at: (@stripe_subscription.pause_collection&.resumes_at ? Time.at(@stripe_subscription.pause_collection&.resumes_at) : nil)
        )
      end

      def unpause
        @stripe_subscription = ::Stripe::Subscription.update(processor_id, {pause_collection: nil}.merge(expand_options), stripe_options)
        pay_subscription.update(pause_behavior: nil, pause_resumes_at: nil)
      end

      def resume
        unless on_grace_period? || paused?
          raise StandardError, "You can only resume subscriptions within their grace period."
        end

        if paused?
          unpause
        else
          @stripe_subscription = ::Stripe::Subscription.update(
            processor_id,
            {
              plan: processor_plan,
              trial_end: (on_trial? ? trial_ends_at.to_i : "now"),
              cancel_at_period_end: false
            }.merge(expand_options),
            stripe_options
          )
        end
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def swap(plan)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        @stripe_subscription = ::Stripe::Subscription.update(
          processor_id,
          {
            cancel_at_period_end: false,
            plan: plan,
            proration_behavior: (prorate ? "create_prorations" : "none"),
            trial_end: (on_trial? ? trial_ends_at.to_i : "now"),
            quantity: quantity
          }.merge(expand_options),
          stripe_options
        )
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Creates a metered billing usage record
      #
      # Uses the first subscription_item ID unless `subscription_item_id: "si_1234"` is passed
      #
      # create_usage_record(quantity: 4, action: :increment)
      # create_usage_record(subscription_item_id: "si_1234", quantity: 100, action: :set)
      def create_usage_record(**options)
        subscription_item_id = options.fetch(:subscription_item_id, subscription_items.first["id"])
        ::Stripe::SubscriptionItem.create_usage_record(subscription_item_id, options, stripe_options)
      end

      # Returns usage record summaries for a subscription item
      def usage_record_summaries(**options)
        subscription_item_id = options.fetch(:subscription_item_id, subscription_items.first["id"])
        ::Stripe::SubscriptionItem.list_usage_record_summaries(subscription_item_id, options, stripe_options)
      end

      # Returns an upcoming invoice for a subscription
      def upcoming_invoice(**options)
        ::Stripe::Invoice.upcoming(options.merge(subscription: processor_id), stripe_options)
      end

      private

      # Options for Stripe requests
      def stripe_options
        {stripe_account: stripe_account}.compact
      end

      def expand_options
        self.class.expand_options
      end
    end
  end
end
