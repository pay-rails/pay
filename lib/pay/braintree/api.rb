module Pay
  module Braintree
    module Api
      def self.set_api_keys
        environment = get_key_for(:environment)
        merchant_id = get_key_for(:merchant_id)
        public_key  = get_key_for(:public_key)
        private_key = get_key_for(:private_key)

        Pay.braintree_gateway = ::Braintree::Gateway.new(
          environment: environment.to_sym,
          merchant_id: merchant_id,
          public_key:  public_key,
          private_key: private_key,
        )
      end

      def self.get_key_for(name)
        env         = Rails.env.to_sym
        secrets     = Rails.application.secrets
        credentials = Rails.application.credentials

        secrets.dig(env, :braintree, name) || credentials.dig(env, :braintree, name) || ENV["BRAINTREE_#{name.upcase}"]
      end
    end
  end
end
