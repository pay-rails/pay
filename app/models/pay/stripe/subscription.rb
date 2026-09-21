module Pay
  module Stripe
    class Subscription < Pay::Subscription
      extend Pay::Sync

      attr_writer :api_record

      def self.sync_from_checkout_session(session_id, stripe_account: nil)
        Pay.deprecator.warn "Pay::Stripe::Subscription.sync_from_checkout_session is deprecated, use Pay::Stripe.sync_checkout_session instead"
        Pay::Stripe.sync_checkout_session(session_id, stripe_account: stripe_account)
      end

      def self.sync(subscription_id, object: nil, name: nil, stripe_account: nil, retries: 1)
        sync_with_retries(retries: retries) do
          subscription = object || ::Stripe::Subscription.retrieve({id: subscription_id}.merge(expand_options), {stripe_account: stripe_account}.compact)
          return unless (pay_customer = find_pay_customer(subscription.customer))
          stripe_account ||= pay_customer.stripe_account

          attributes = {
            object: subscription.to_hash,
            application_fee_percent: subscription.application_fee_percent,
            created_at: Time.at(subscription.created),
            processor_plan: subscription.items.first.price.id,
            quantity: subscription.items.first.try(:quantity) || 0,
            status: subscription.status,
            stripe_account: stripe_account,
            metadata: subscription.metadata,
            metered: false,
            pause_behavior: subscription.pause_collection&.behavior,
            pause_resumes_at: (subscription.pause_collection&.resumes_at ? Time.at(subscription.pause_collection&.resumes_at) : nil),
            current_period_start: (subscription.items.first.current_period_start ? Time.at(subscription.items.first.current_period_start) : nil),
            current_period_end: (subscription.items.first.current_period_end ? Time.at(subscription.items.first.current_period_end) : nil)
          }

          # Subscriptions that have ended should have their trial ended at the
          # same time if they were still on trial (if you cancel a
          # subscription, your are cancelling your trial as well at the same
          # instant). This avoids canceled subscriptions responding `true`
          # to #on_trial? due to the `trial_ends_at` being left set in the
          # future.
          if subscription.trial_end
            trial_ended_at = [subscription.ended_at, subscription.trial_end].compact.min
            attributes[:trial_ends_at] = Time.at(trial_ended_at)
          else
            attributes[:trial_ends_at] = nil
          end

          subscription.items.auto_paging_each do |subscription_item|
            next if attributes[:metered]
            attributes[:metered] = true if subscription_item.price.try(:recurring).try(:usage_type) == "metered"
          end

          attributes[:ends_at] = if subscription.ended_at
            # Fully cancelled subscription
            Time.at(subscription.ended_at)
          elsif subscription.cancel_at
            # subscription cancelling in the future
            Time.at(subscription.cancel_at)
          elsif subscription.cancel_at_period_end
            # Subscriptions cancelling in the future
            Time.at(subscription.items.first.current_period_end)
          end

          # Sync payment method if directly attached to subscription
          if subscription.default_payment_method
            if subscription.default_payment_method.is_a? String
              Pay::Stripe::PaymentMethod.sync(subscription.default_payment_method, stripe_account: stripe_account)
              attributes[:payment_method_id] = subscription.default_payment_method
            else
              Pay::Stripe::PaymentMethod.sync(subscription.default_payment_method.id, object: subscription.default_payment_method, stripe_account: stripe_account)
              attributes[:payment_method_id] = subscription.default_payment_method.id
            end
          end

          # Update or create the subscription
          pay_subscription = find_by(customer: pay_customer, processor_id: subscription.id)
          if pay_subscription
            # If pause behavior is changing to `void`, record the pause start date
            # Any other pause status (or no pause at all) should have nil for start
            if pay_subscription.pause_behavior != attributes[:pause_behavior]
              attributes[:pause_starts_at] = if attributes[:pause_behavior] == "void"
                Time.at(subscription.items.first.current_period_end)
              end
            end

            pay_subscription.with_lock { pay_subscription.update!(attributes) }
          else
            # Allow setting the subscription name in metadata, otherwise use the default
            name ||= subscription.metadata["pay_name"] || Pay.default_product_name
            pay_subscription = create!(attributes.merge(customer: pay_customer, name: name, processor_id: subscription.id))
          end

          # Cache the Stripe subscription on the Pay::Subscription that we return
          pay_subscription.api_record = subscription

          # Sync the latest charge if we already have it loaded (like during subscrbe), otherwise, let webhooks take care of creating it
          if (invoice = subscription.try(:latest_invoice))
            Array(invoice.try(:payments)).each do |invoice_payment|
              next unless invoice_payment.status == "paid"

              case invoice_payment.payment.type
              when "payment_intent"
                Pay::Stripe::Charge.sync_payment_intent(invoice_payment.payment.payment_intent, stripe_account: stripe_account)
              when "charge"
                Pay::Stripe::Charge.sync(invoice_payment.payment.charge, stripe_account: stripe_account)
              end
            end
          end

          pay_subscription
        end
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Common expand options for all requests that create, retrieve, or update a Stripe Subscription
      def self.expand_options
        {
          expand: [
            "default_payment_method",
            "discounts",
            "latest_invoice.confirmation_secret",
            "latest_invoice.payments",
            "latest_invoice.total_discount_amounts.discount",
            "pending_setup_intent",
            "schedule"
          ]
        }
      end

      def stripe_object
        sync! if object.nil?
        ::Stripe::Subscription.construct_from(object)
      end

      def sync!(**options)
        super(**options.with_defaults(stripe_account: stripe_account))
      end

      def api_record(**options)
        @api_record ||= ::Stripe::Subscription.retrieve(options.with_defaults(id: processor_id).merge(expand_options), {stripe_account: stripe_account}.compact)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Returns a SetupIntent or PaymentIntent client secret for the subscription
      def client_secret
        api_record&.pending_setup_intent&.client_secret || api_record&.latest_invoice&.confirmation_secret&.client_secret
      end

      # Sets the default_payment_method on a subscription
      # Pass an empty string to unset
      def update_payment_method(id)
        @api_record = ::Stripe::Subscription.update(processor_id, {default_payment_method: id}.merge(expand_options), stripe_options)
        update(payment_method_id: @api_record.default_payment_method&.id)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Marks a subscription to cancel at period end
      #
      # If subscription is already past_due, the subscription will be cancelled immediately
      # To disable this, pass past_due_cancel_now: false
      def cancel(**options)
        return if canceled?

        if past_due? && options.fetch(:past_due_cancel_now, true)
          cancel_now!
        else
          @api_record = ::Stripe::Subscription.update(processor_id, {cancel_at_period_end: true}.merge(expand_options), stripe_options)
          update(ends_at: Time.at(@api_record.cancel_at))
        end
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Cancels a subscription immediately
      #
      # cancel_now!(prorate: true)
      # cancel_now!(invoice_now: true)
      def cancel_now!(**options)
        return if canceled? && ends_at.past?

        @api_record = ::Stripe::Subscription.cancel(processor_id, options.merge(expand_options), stripe_options)
        update(
          trial_ends_at: (@api_record.trial_end ? Time.at(@api_record.trial_end) : nil),
          ends_at: Time.at(@api_record.ended_at),
          status: @api_record.status
        )
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # This updates a SubscriptionItem's quantity in Stripe
      #
      # Defaults to the first SubscriptionItem. Pass subscription_item_id: to update a different one
      # (Stripe no longer accepts a top-level quantity on the subscription itself)
      def change_quantity(quantity, **options)
        subscription_item_id = options.delete(:subscription_item_id) || subscription_items.first.id
        ::Stripe::SubscriptionItem.update(subscription_item_id, options.merge(quantity: quantity), stripe_options)
        @api_record = nil
        update(quantity: quantity)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def on_grace_period?
        (ends_at? && ends_at > Time.current) || (paused? && will_pause?)
      end

      def pause_active?
        paused? && (pause_starts_at.nil? || Time.current.after?(pause_starts_at))
      end

      def will_pause?
        pause_starts_at? && Time.current < pause_starts_at
      end

      def paused?
        pause_behavior == "void"
      end

      # Pauses a Stripe subscription
      #
      # pause(behavior: "mark_uncollectible")
      # pause(behavior: "keep_as_draft")
      # pause(behavior: "void")
      # pause(behavior: "mark_uncollectible", resumes_at: 1.month.from_now)
      #
      # `void` - If you can’t provide your services for a certain period of time, you can void invoices that are created by your subscriptions so that your customers aren’t charged.
      # `keep_as_draft` - If you want to temporarily offer your services for free and collect payments later
      # `mark_uncollectible` - If you want to offer your services for free
      #
      # pause_behavior of `void` is considered active until the end of the current period and not active after that. The current_period_end is stored as `pause_starts_at`
      # Other pause_behaviors do not set `pause_starts_at` because they are used for offering free services
      #
      # https://docs.stripe.com/billing/subscriptions/pause-payment
      def pause(**options)
        attributes = {pause_collection: options.reverse_merge(behavior: "void")}
        @api_record = ::Stripe::Subscription.update(processor_id, attributes.merge(expand_options), stripe_options)
        behavior = @api_record.pause_collection&.behavior
        update(
          pause_behavior: behavior,
          pause_resumes_at: (@api_record.pause_collection&.resumes_at ? Time.at(@api_record.pause_collection&.resumes_at) : nil),
          pause_starts_at: ((behavior == "void") ? Time.at(@api_record.items.first.current_period_end) : nil)
        )
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Unpauses a subscription
      #
      # https://docs.stripe.com/billing/subscriptions/pause-payment#unpausing
      def unpause
        @api_record = ::Stripe::Subscription.update(processor_id, {pause_collection: ""}.merge(expand_options), stripe_options)
        update(
          pause_behavior: nil,
          pause_resumes_at: nil,
          pause_starts_at: nil
        )
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def resumable?
        on_grace_period? || paused?
      end

      def resume
        unless resumable?
          raise Error, "You can only resume subscriptions within their grace period."
        end

        if paused?
          unpause
        else
          @api_record = ::Stripe::Subscription.update(processor_id, {
            trial_end: (on_trial? ? trial_ends_at.to_i : "now"),
            cancel_at_period_end: false
          }.merge(expand_options),
            stripe_options)
        end
        update(ends_at: nil, status: @api_record.status)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def swap(plan, **options)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        prorate = options.delete(:prorate) { true }
        proration_behavior = options.delete(:proration_behavior) || (prorate ? "always_invoice" : "none")

        @api_record = ::Stripe::Subscription.update(
          processor_id,
          {
            cancel_at_period_end: false,
            items: [{id: subscription_items.first.id, plan: plan, quantity: quantity}],
            proration_behavior: proration_behavior,
            trial_end: (on_trial? ? trial_ends_at.to_i : "now")
          }.merge(expand_options).merge(options),
          stripe_options
        )

        # Validate that swap was successful and handle SCA if needed
        if (payment_intent_id = @api_record.latest_invoice.payments.first&.payment&.payment_intent)
          Pay::Payment.from_id(payment_intent_id, stripe_account: stripe_account).validate
        end

        sync!(object: @api_record)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def subscription_items
        stripe_object.items
      end

      # Returns the first metered subscription item
      def metered_subscription_item
        subscription_items.auto_paging_each do |subscription_item|
          return subscription_item if subscription_item.price.try(:recurring).try(:usage_type) == "metered"
        end
      end

      def preview_invoice(**options)
        ::Stripe::Invoice.create_preview(options.merge(subscription: processor_id), stripe_options)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Retries the latest invoice for a Past Due subscription and attempts to pay it
      def retry_failed_payment(payment_intent_id: nil)
        payment_intent_id ||= api_record.latest_invoice.payments.first.payment.payment_intent
        payment_intent = ::Stripe::PaymentIntent.retrieve({id: payment_intent_id}, stripe_options)

        payment_intent = if payment_intent.status == "requires_payment_method"
          payment_method = customer.default_payment_method
          raise Pay::Stripe::Error, "no default payment method to retry the payment with" if payment_method.nil?

          ::Stripe::PaymentIntent.confirm(payment_intent_id, {payment_method: payment_method.processor_id}, stripe_options)
        else
          ::Stripe::PaymentIntent.confirm(payment_intent_id, {}, stripe_options)
        end
        Pay::Payment.new(payment_intent).validate
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Looks up open invoices for a subscription and attempts to pay them
      #
      # Invoices no longer expose a `payment_intent` directly, so the PaymentIntent is looked up through the invoice's payments
      def pay_open_invoices
        ::Stripe::Invoice.list({subscription: processor_id, status: :open, expand: ["data.payments"]}, stripe_options).auto_paging_each do |invoice|
          payment_intent_id = invoice.payments.first&.payment&.payment_intent
          retry_failed_payment(payment_intent_id: payment_intent_id) if payment_intent_id
        end
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      # Returns the Stripe::PaymentIntent for the latest invoice, if there is one
      def latest_payment
        payment_intent_id = api_record.latest_invoice&.payments&.first&.payment&.payment_intent
        ::Stripe::PaymentIntent.retrieve({id: payment_intent_id}, stripe_options) if payment_intent_id
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
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

ActiveSupport.run_load_hooks :pay_stripe_subscription, Pay::Stripe::Subscription
