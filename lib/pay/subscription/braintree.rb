module Pay
  module Subscription
    module Braintree
      def braintree_cancel
        subscription = processor_subscription

        if on_trial?
          gateway.subscription.cancel(subscription.id)

        else
          gateway.subscription.update(subscription.id, {
            number_of_billing_cycles: subscription.current_billing_cycle
          })

          update(ends_at: subscription.billing_period_end_date)
        end
      end

      def braintree_cancel_now!
        gateway.subscription.cancel(processor_subscription.id)
      end

      def braintree_resume
        subscription = processor_subscription

        gateway.subscription.update(subscription.id, {
          never_expires: true,
          number_of_billing_cycles: null
        })
      end

      def braintree_swap(plan)
        if on_grace_period? && processor_plan == plan
          resume
        end

        if !active?
          owner.subscribe(name, plan, 'braintree', trial_period: false)
          return
        end

        braintree_plan = find_braintree_plan(plan)

        if would_change_billing_frequency?(braintree_plan) && prorate?
          swap_across_frequencies(braintree_plan)
        end

        subscription = processor_subscription

        result = gateway.subscription.update(subscription.id, {
          plan_id: braintree_plan.id,
          price: braintree_plan.price,
          never_expires: true,
          number_of_billing_cycles: nil,
          options: {
            prorate_charges: prorate?,
          }
        })

        if result.success?
          update(processor_plan: braintree_plan.id, ends_at: nil)
        else
          raise StandardError, "Braintree failed to swap plans: #{result.message}"
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
          @braintree_plans.find{ |p| p.id == id }
        end

        # Helper methods for swapping plans
        def switching_to_monthly_plan?(current_plan, plan)
          current_plan.billing_frequency == 12 && plan.billing_frequency == 1
        end

        def discount_for_switching_to_monthly(current_plan, plan)
          cycles = (money_remaining_on_yearly_plan(current_plan) / plan.price).floor
          Struct.new(
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
            if discount.id == 'plan-credit'
              amount += discount.amount * discount.number_of_billing_cycles
            end
          end

          Struct.new(
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
                    inherited_from_id: 'plan-credit',
                    amount: discount.amount,
                    number_of_billing_cycles: discount.number_of_billing_cycles
                  }
                ]
              }
            }
          end

          cancel_now!

          owner.subscribe(name, plan.id, options)
        end
    end
  end
end
