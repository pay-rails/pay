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
        after_update :update_processor_email
      end

      private

        def update_processor_email
          # Only update if the processor id is the same
          # This prevents duplicate API hits if this is their first time
          if processor_id? && !processor_id_changed? && saved_change_to_email?
            send("update_#{processor}_email!")
          end
        end

    end
  end
end
