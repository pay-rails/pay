module Pay
  class Engine < ::Rails::Engine
    isolate_namespace Pay

    config.autoload_paths += Dir["#{config.root}/lib/**/"]


    initializer 'pay.processors' do
      # Include processor backends
      if defined? Stripe
        Dir[File.join(__dir__, 'pay/stripe', '**', '*.rb')].each { |file| require file }

        Pay.user_model.include Pay::Stripe::Billable
        Pay.subscription_model.include Pay::Stripe::Subscription
      end

      if defined? Braintree
        Dir[File.join(__dir__, 'pay/braintree', '**', '*.rb')].each { |file| require file }

        Pay.user_model.include Pay::Braintree::Billable
        Pay.subscription_model.include Pay::Braintree::Subscription
      end
    end
  end
end
