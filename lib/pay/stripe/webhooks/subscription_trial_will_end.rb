module Pay
  module Stripe
    module Webhooks
      class SubscriptionTrialWillEnd
        def call(event)
          object = event.data.object

          pay_subscription = Pay::Subscription.find_by_processor_and_id(:stripe, object.id)
          return if pay_subscription.nil?

          pay_subscription.sync!(stripe_account: event.try(:account))

          pay_user_mailer = Pay.mailer.with(pay_customer: pay_subscription.customer, pay_subscription: pay_subscription)

          if Pay.send_email?(:subscription_trial_will_end, pay_subscription) && pay_subscription.on_trial?
            pay_user_mailer.subscription_trial_will_end.deliver_later
          elsif Pay.send_email?(:subscription_trial_ended, pay_subscription) && pay_subscription.trial_ended?
            pay_user_mailer.subscription_trial_ended.deliver_later
          end
        end
      end
    end
  end
end
