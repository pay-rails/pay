module Pay
  # Shared skeleton for the processor Charge.sync, Subscription.sync, and PaymentMethod.sync class methods
  module Sync
    # Runs the sync block, retrying it when a webhook and an API call race to
    # create the same record. The block retrieves the processor's object itself
    # when the caller didn't pass one in, so each retry gets a fresh read.
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

    # The Pay::Customer for this processor, or nil when the ID is blank or the customer isn't in the database
    def find_pay_customer(processor_id)
      Pay::Customer.find_by(processor: pay_processor, processor_id: processor_id) if processor_id.present?
    end

    # "stripe" for Pay::Stripe::Charge, "paddle_billing" for Pay::PaddleBilling::Subscription, and so on
    def pay_processor
      name.deconstantize.demodulize.underscore
    end
  end
end
