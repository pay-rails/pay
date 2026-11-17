module Pay
  module Billable
    module SyncCustomer
      # Syncs customer details to the payment processor.
      # This way they're kept in sync and email notifications are
      # always sent to the correct email address after an update.

      extend ActiveSupport::Concern

      included do
        after_update_commit :enqueue_customer_sync_job, if: :pay_should_sync_customer?
      end

      def pay_should_sync_customer?
        try(:saved_change_to_email?)
      end

      private

      def enqueue_customer_sync_job
        ActiveJob.perform_all_later(pay_customers.active.ids.map { |id| CustomerSyncJob.new(id) })
      end
    end
  end
end
