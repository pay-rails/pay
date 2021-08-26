# A subscription successfully moves to the next billing cycle. This will also occur when either a new transaction is created mid-cycle due to proration on an upgrade or a billing cycle is skipped due to the presence of a negative balance that covers the cost of the subscription.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionChargedSuccessfully
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay::Subscription.find_by_processor_and_id(:braintree, subscription.id)
          return unless pay_subscription.present?

          pay_customer = pay_subscription.customer
          charge = Pay::Braintree::Billable.new(pay_customer).save_transaction(subscription.transactions.first)

          if Pay.send_emails
            Pay::UserMailer.with(billable: pay_customer.owner, charge: charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
