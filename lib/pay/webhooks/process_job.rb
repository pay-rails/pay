module Pay
  module Webhooks
    class ProcessJob < ApplicationJob
      def perform(pay_webhook)
        pay_webhook.process!
      end
    end
  end
end
