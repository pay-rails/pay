module Pay
  module Merchant
    extend ActiveSupport::Concern

    included do
      store_accessor :pay_data, :stripe_connect_account_id
      store_accessor :pay_data, :onboarding_complete
      store_accessor :pay_data, :marketplace_capable
    end

    def merchant
      @merchant ||= merchant_processor_for(merchant_processor).new(self)
    end

    def merchant_processor_for(name)
      "Pay::#{name.to_s.classify}::Merchant".constantize
    end
  end
end
