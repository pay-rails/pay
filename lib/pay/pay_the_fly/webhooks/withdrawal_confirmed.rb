# frozen_string_literal: true

module Pay
  module PayTheFly
    module Webhooks
      class WithdrawalConfirmed
        def call(event)
          data = event.is_a?(Hash) ? event : event.to_h
          data = data.with_indifferent_access if data.respond_to?(:with_indifferent_access)

          # Only process confirmed withdrawal events (tx_type: 2 = withdrawal)
          return unless data["tx_type"].to_i == 2
          return unless data["confirmed"] == true || data["confirmed"] == "true"

          Pay::PayTheFly::Charge.sync_withdrawal_from_webhook(data)
        end
      end
    end
  end
end
