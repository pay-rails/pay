# A subscription successfully moves to the next billing cycle. This will also occur when either a new transaction is created mid-cycle due to proration on an upgrade or a billing cycle is skipped due to the presence of a negative balance that covers the cost of the subscription.

module Pay
  module Braintree
    module Webhooks
      class SubscriptionChargedSuccessfully
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay.subscription_model.find_by(processor: :braintree, processor_id: subscription.id)
          return unless pay_subscription.present?

          billable = pay_subscription.owner
          charge = Pay::Braintree::Billable.new(billable).save_transaction(subscription.transactions.first)

          if Pay.send_emails
            Pay::UserMailer.with(billable: billable, charge: charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
