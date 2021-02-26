module Pay
  module Webhooks
    autoload :Delegator, "pay/webhooks/delegator"

    class << self
      delegate :configure, :instrument, to: :delegator

      def delegator
        @delegator ||= Delegator.new
      end
    end
  end
end
