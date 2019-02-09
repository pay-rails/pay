module Pay
  class Engine < ::Rails::Engine
    engine_name 'pay'

    initializer 'pay.processors' do
      # Include processor backends
      require 'pay/stripe'    if defined? ::Stripe
      require 'pay/braintree' if defined? ::Braintree
    end

    config.to_prepare do
      Pay::Stripe.setup    if defined? ::Stripe
      Pay::Braintree.setup if defined? ::Braintree

      Pay.charge_model.include Pay::Receipts if defined? Receipts::Receipt
    end
  end
end
