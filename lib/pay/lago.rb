module Pay
  module Lago
    autoload :Billable, "pay/lago/billable"
    autoload :Charge, "pay/lago/charge"
    autoload :Error, "pay/lago/error"
    autoload :PaymentMethod, "pay/lago/payment_method"
    autoload :Subscription, "pay/lago/subscription"
    autoload :Merchant, "pay/lago/merchant"
    
    extend Env
    
    def self.enabled?
      return false unless Pay.enabled_processors.include?(:lago) && defined?(::Lago)
      true
    end

    def self.client
      @client || setup
    end
    
    def self.setup
      @client = ::Lago::Api::Client.new(api_key: api_key, api_url: api_url)
    end
    
    def self.api_key
      find_value_by_name(:lago, :api_key)
    end

    def self.api_url
      find_value_by_name(:lago, :api_url)
    end

    # Helpers for working with Lago client
    def self.openstruct_to_h(ostruct)
      return ostruct.to_h.transform_values {|value| openstruct_to_h(value) } if ostruct.is_a?(OpenStruct) || ostruct.is_a?(Hash)
      return ostruct.map { |value| openstruct_to_h(value) } if ostruct.is_a?(Array)
      ostruct
    end
  end
end
