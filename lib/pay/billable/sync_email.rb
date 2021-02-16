module Pay
  module Billable
    module SyncEmail
      # Sync email address changes from the model to the processor.
      # This way they're kept in sync and email notifications are
      # always sent to the correct email address after an update.
      #
      # Processor classes simply need to implement a method named:
      #
      # update_PROCESSOR_email!
      #
      # This method should take the email address on the billable
      # object and update the associated API record.

      extend ActiveSupport::Concern

      included do
        after_update :enqeue_sync_email_job, if: :should_sync_email_with_processor?
      end

      def should_sync_email_with_processor?
        try(:saved_change_to_email?)
      end

      def sync_email_with_processor
        payment_processor.update_email!
      end

      private

      def enqeue_sync_email_job
        # Only update if the processor id is the same
        # This prevents duplicate API hits if this is their first time
        if processor_id? && !saved_change_to_processor_id? && saved_change_to_email?
          EmailSyncJob.perform_later(id, self.class.name)
        end
      end
    end
  end
end
