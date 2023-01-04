module Pay
  module Braintree
    class Subscription
      attr_reader :pay_subscription

      delegate :active?,
        :canceled?,
        :on_grace_period?,
        :customer,
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
        :trial_ends_at,
        to: :pay_subscription

      def self.sync(subscription_id, object: nil, name: nil, try: 0, retries: 1)
        object ||= Pay.braintree_gateway.subscription.find(subscription_id)

        # Retrieve Pay::Customer
        payment_method = Pay.braintree_gateway.payment_method.find(object.payment_method_token)
        pay_customer = Pay::Customer.find_by(processor: :braintree, processor_id: payment_method.customer_id)
        return unless pay_customer

        attributes = {
          created_at: object.created_at,
          current_period_end: object.billing_period_end_date,
          current_period_start: object.billing_period_start_date,
          processor_plan: object.plan_id,
          status: object.status.underscore,
          trial_ends_at: (object.created_at + object.trial_duration.send(object.trial_duration_unit) if object.trial_period)
        }

        # Set ends at to paid through date
        # On trial, paid through date is nil, so fallback to updated_at
        if object.status == "Canceled"
          attributes[:ends_at] = object.paid_through_date&.end_of_day || object.updated_at
        end

        pay_subscription = pay_customer.subscriptions.find_by(processor_id: object.id)
        if pay_subscription
          pay_subscription.with_lock { pay_subscription.update!(attributes) }
        else
          name ||= Pay.default_product_name
          pay_subscription = pay_customer.subscriptions.create!(attributes.merge(name: name, processor_id: object.id))
        end

        pay_subscription
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription(**options)
        gateway.subscription.find(processor_id)
      end

      def cancel(**options)
        subscription = processor_subscription

        if on_trial?
          gateway.subscription.cancel(processor_subscription.id)
          pay_subscription.update(status: :canceled, ends_at: trial_ends_at)
        else
          gateway.subscription.update(subscription.id, {
            number_of_billing_cycles: subscription.current_billing_cycle
          })
          pay_subscription.update(status: :canceled, ends_at: subscription.billing_period_end_date.to_date)
        end
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end

      def cancel_now!(**options)
        gateway.subscription.cancel(processor_subscription.id)
        ends_at = Time.current
        pay_subscription.update!(
          status: :canceled,
          trial_ends_at: (ends_at if pay_subscription.trial_ends_at?),
          ends_at: ends_at
        )
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end

      def change_quantity(quantity, **options)
        raise NotImplementedError, "Braintree does not support setting quantity on subscriptions"
      end

      def on_grace_period?
        canceled? && Time.current < ends_at
      end

      def paused?
        false
      end

      def pause
        raise NotImplementedError, "Braintree does not support pausing subscriptions"
      end

      def resume
        unless on_grace_period?
          raise StandardError, "You can only resume subscriptions within their grace period."
        end

        if canceled? && on_trial?
          duration = trial_ends_at.to_date - Date.today

          customer.subscribe(
            name: name,
            plan: processor_plan,
            trial_period: true,
            trial_duration: duration.to_i,
            trial_duration_unit: :day
          )
        else
          subscription = processor_subscription

          gateway.subscription.update(subscription.id, {
            never_expires: true,
            number_of_billing_cycles: nil
          })
        end

        pay_subscription.update(status: :active)
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end

      def swap(plan, **options)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        if on_grace_period? && processor_plan == plan
          resume
          return
        end

        unless active?
          customer.subscribe(name: name, plan: plan, trial_period: false)
          return
        end

        braintree_plan = find_braintree_plan(plan)

        if would_change_billing_frequency?(braintree_plan) && prorate?
          swap_across_frequencies(braintree_plan)
          return
        end

        subscription = processor_subscription

        result = gateway.subscription.update(subscription.id, {
          plan_id: braintree_plan.id,
          price: braintree_plan.price,
          never_expires: true,
          number_of_billing_cycles: nil,
          options: {
            prorate_charges: prorate?
          }
        })
        raise Error, "Braintree failed to swap plans: #{result.message}" unless result.success?

        pay_subscription.update(processor_plan: plan, ends_at: nil, status: :active)
      rescue ::Braintree::BraintreeError => e
        raise Pay::Braintree::Error, e
      end

      # Retries the latest invoice for a Past Due subscription
      def retry_failed_payment
        result = gateway.subscription.retry_charge(
          processor_id,
          nil, # amount if different
          true # submit for settlement
        )

        if result.success?
          pay_subscription.update(status: :active)
        end
      end

      private

      def gateway
        Pay.braintree_gateway
      end

      def would_change_billing_frequency?(plan)
        plan.billing_frequency != find_braintree_plan(processor_plan).billing_frequency
      end

      def find_braintree_plan(id)
        @braintree_plans ||= gateway.plan.all
        @braintree_plans.find { |p| p.id == id }
      end

      # Helper methods for swapping plans
      def switching_to_monthly_plan?(current_plan, plan)
        current_plan.billing_frequency == 12 && plan.billing_frequency == 1
      end

      def discount_for_switching_to_monthly(current_plan, plan)
        cycles = (money_remaining_on_yearly_plan(current_plan) / plan.price).floor
        OpenStruct.new(
          amount: plan.price,
          number_of_billing_cycles: cycles
        )
      end

      def money_remaining_on_yearly_plan(current_plan)
        end_date = processor_subscription.billing_period_end_date.to_date
        (current_plan.price / 365) * (end_date - Date.today)
      end

      def discount_for_switching_to_yearly
        amount = 0

        processor_subscription.discounts.each do |discount|
          if discount.id == "plan-credit"
            amount += discount.amount * discount.number_of_billing_cycles
          end
        end

        OpenStruct.new(
          amount: amount,
          number_of_billing_cycles: 1
        )
      end

      def swap_across_frequencies(plan)
        current_plan = find_braintree_plan(processor_plan)

        discount = if switching_to_monthly_plan?(current_plan, plan)
          discount_for_switching_to_monthly(current_plan, plan)
        else
          discount_for_switching_to_yearly
        end

        options = {}

        if discount.amount > 0 && discount.number_of_billing_cycles > 0
          options = {
            discounts: {
              add: [
                {
                  inherited_from_id: "plan-credit",
                  amount: discount.amount.round(2),
                  number_of_billing_cycles: discount.number_of_billing_cycles
                }
              ]
            }
          }
        end

        # If subscribe fails we will raise a Pay::Braintree::Error and not cancel the current subscription
        customer.subscribe(**options.merge(name: name, plan: plan.id))

        cancel_now!
      end
    end
  end
end
