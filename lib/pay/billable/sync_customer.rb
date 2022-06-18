module Pay
  module Billable
    module SyncCustomer
      # Syncs customer details to the payment processor.
      # This way they're kept in sync and email notifications are
      # always sent to the correct email address after an update.

      extend ActiveSupport::Concern

      included do
        after_commit :enqeue_customer_sync_job, if: :pay_should_sync_customer?
      end

      def pay_should_sync_customer?
        try(:saved_change_to_email?)
      end

      private

      def enqeue_customer_sync_job
        if pay_should_sync_customer?
          # Queue job to update each payment processor for this customer
          pay_customers.pluck(:id).each do |pay_customer_id|
            CustomerSyncJob.perform_later(pay_customer_id)
          end
        end
      end
    end
  end
end
