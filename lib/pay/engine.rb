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

      raise StandardError, "\n\nThe Pay gem requires Stripe or Braintree at a minimum to use.\n\nAdd at least one of the following to your gemfile, bundle, and restart your app.\n\ngem 'stripe', '< 5.0', '>= 2.8'\ngem 'stripe_event'\n\ngem 'braintree', '< 3.0', '>= 2.92.0'" unless defined?(Stripe) || defined?(Braintree)
    end
  end
end
