module Pay
  module Stripe
    module Api
      def self.set_api_keys
        env         = Rails.env.to_sym
        secrets     = Rails.application.secrets
        credentials = Rails.application.credentials

        ::Stripe.api_key = ENV["STRIPE_PRIVATE_KEY"] || secrets.dig(env, :stripe, :private_key) || credentials.dig(env, :stripe, :private_key)
      end
    end
  end
end
