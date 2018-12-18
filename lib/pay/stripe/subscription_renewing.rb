module Pay
  module Stripe
    class SubscriptionRenewing
      def call(event)
        object = event.data.object
        subscription = ::Subscription.find_by(processor: :stripe, processor_id: object.id)
        notify_user(subscription.user, subscription) if subscription.present?
      end

      def notify_user(user, subscription)
        if Pay.send_emails
          Pay::UserMailer.subscription_renewing(user, subscription).deliver_later
        end
      end
    end
  end
end
