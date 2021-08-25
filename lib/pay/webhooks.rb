module Pay
  module Webhooks
    autoload :Delegator, "pay/webhooks/delegator"
    autoload :ProcessJob, "pay/webhooks/process_job"

    class << self
      delegate :configure, :instrument, to: :delegator

      def delegator
        @delegator ||= Delegator.new
      end
    end
  end
end
