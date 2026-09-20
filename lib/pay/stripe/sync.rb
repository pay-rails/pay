module Pay
  module Stripe
    # Shared skeleton for Charge.sync, Subscription.sync, and PaymentMethod.sync
    module Sync
      # Runs the sync block, retrying it when a webhook and an API call race to
      # create the same record. The block is responsible for retrieving the
      # Stripe object when the caller didn't pass one in, so each retry gets a
      # fresh read from the API.
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

      # Looks up the Pay::Customer for a Stripe object. Returns nil when the
      # object has no customer or the customer isn't in the database.
      def find_pay_customer(object)
        if object.customer.blank?
          Rails.logger.debug "Stripe #{object.object} #{object.id} does not have a customer"
          return
        end

        pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: object.customer)
        if pay_customer.blank?
          Rails.logger.debug "Pay::Customer #{object.customer} is not in the database while syncing Stripe #{object.object} #{object.id}"
          return
        end

        pay_customer
      end
    end
  end
end
