module Pay
  class Engine < ::Rails::Engine
    isolate_namespace Pay

    config.autoload_paths += Dir["#{config.root}/lib/**/"]


    initializer 'pay.processors' do
      # Include processor backends
      if defined? Stripe
        Dir[File.join(__dir__, 'pay/stripe', '**', '*.rb')].each { |file| require file }

        Pay.charge_model.include Pay::Stripe::Charge
        Pay.subscription_model.include Pay::Stripe::Subscription
        Pay.user_model.include Pay::Stripe::Billable

        Pay::Stripe::Api.set_api_keys
      end

      if defined? Braintree
        Dir[File.join(__dir__, 'pay/braintree', '**', '*.rb')].each { |file| require file }

        Pay.charge_model.include Pay::Braintree::Charge
        Pay.subscription_model.include Pay::Braintree::Subscription
        Pay.user_model.include Pay::Braintree::Billable
      end

      if defined?(Receipts::Receipt)
        Pay.charge_model.include Pay::Receipts
      end
    end
  end
end
