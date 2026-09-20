module Pay
  module Stripe
    # Shared skeleton for Charge.sync, Subscription.sync, and PaymentMethod.sync
    module Sync
      # Runs the sync block, retrying it when a webhook and an API call race to
      # create the same record. The block retrieves the Stripe object itself when
      # the caller didn't pass one in, so each retry gets a fresh read from the
      # API, and requests made during the sync use the customer's Connect account.
      def sync_with_retries(retries: 1)
        try = 0
        begin
          yield
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
          try += 1
          raise if try > retries
          sleep 0.15 * try
          retry
        end
      end

      # The Pay::Customer for a Stripe object, or nil when the object has no customer or the customer isn't in the database
      def find_pay_customer(object)
        Pay::Customer.find_by(processor: :stripe, processor_id: object.customer) if object.customer.present?
      end
    end
  end
end
