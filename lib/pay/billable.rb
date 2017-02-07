module Pay
  module Billable
    extend ActiveSupport::Concern

    included do
      has_many :subscriptions
    end

    def subscribe(name, plan_id, token, options = {})
    end

    def subscribed?(name = "default", plan = nil)
      subscription = subscriptions.find_by(name: name)

      return false if subscription.nil?
      return subscription.valid if plan.nil?

      subscription.valid && subscription.processor_plan == plan
    end
  end
end
