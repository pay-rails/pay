module Pay
  module PaddleBilling
    module Webhooks
      # Refunds are adjustments that may need approval, so re-sync the charge once one is approved
      # Auto-approved refunds only send adjustment.created, so both events are handled
      class Adjustment
        def call(event)
          return unless event.action == "refund" && event.status == "approved"

          Pay::PaddleBilling::Charge.sync(event.transaction_id)
        end
      end
    end
  end
end
