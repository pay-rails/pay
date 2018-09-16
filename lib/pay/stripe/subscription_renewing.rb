module Pay
  module Stripe
    class SubscriptionRenewing
      def call(event)
        object = event.data.object
        subscription = Subscription.find_by(stripe_id: object.subscription)
        notify_user(subscription.user, subscription) if subscription.present?
      end

      def notify_user(user, subscription)
        # Pay::UserMailer.subscription_renewing(subscription).deliver_later
      end
    end
  end
end
