# frozen_string_literal: true

module Pay
  class Engine < ::Rails::Engine
    engine_name "pay"

    initializer "pay.processors" do |app|
      if Pay.automount_routes
        app.routes.append do
          mount Pay::Engine, at: Pay.routes_path, as: "pay"
        end
      end

      # Include the pay attributes for ActiveRecord models
      ActiveSupport.on_load(:active_record) do
        include Pay::Attributes
      end
    end

    initializer "pay.deprecator" do |app|
      app.deprecators[:pay] = Pay.deprecator if app.respond_to?(:deprecators)
    end

    RECEIPTS_VERSION = [">= 2", "< 4"]

    initializer "pay.receipts" do
      if defined?(::Receipts::VERSION)
        raise "[Pay] receipts gem must be version #{RECEIPTS_VERSION.join(", ")}" unless Pay::Engine.version_matches?(required: RECEIPTS_VERSION, current: ::Receipts::VERSION)

        ActiveSupport.on_load :pay_charge do
          include Pay::Receipts
        end
      end
    end

    config.after_initialize do
      ActiveSupport.run_load_hooks(:pay, Pay)
    end

    # Add webhook subscribers before app initializers define extras
    # This keeps the processing in order so that changes have happened before user-defined webhook processors
    config.before_initialize do
      Pay::Stripe.configure_webhooks if Pay::Stripe.enabled?
      Pay::Braintree.configure_webhooks if Pay::Braintree.enabled?
      Pay::PaddleBilling.configure_webhooks if Pay::PaddleBilling.enabled?
      Pay::PaddleClassic.configure_webhooks if Pay::PaddleClassic.enabled?
      Pay::LemonSqueezy.configure_webhooks if Pay::LemonSqueezy.enabled?
    end

    config.to_prepare do
      Pay::Stripe.setup if Pay::Stripe.enabled?
      Pay::Braintree.setup if Pay::Braintree.enabled?
      Pay::PaddleBilling.setup if Pay::PaddleBilling.enabled?
      Pay::LemonSqueezy.setup if Pay::LemonSqueezy.enabled?
    end

    # Determines if a gem version matches requirements
    # Used for verifying that dependencies are correct
    def version_matches?(current:, required:)
      Gem::Dependency.new("gem", required).match? "gem", current
    end
  end
end
