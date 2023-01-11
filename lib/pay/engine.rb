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

    # Add webhook subscribers before app initializers define extras
    # This keeps the processing in order so that changes have happened before user-defined webhook processors
    config.before_initialize do
      Pay::Stripe.configure_webhooks if Pay::Stripe.enabled?
      Pay::Braintree.configure_webhooks if Pay::Braintree.enabled?
      Pay::Paddle.configure_webhooks if Pay::Paddle.enabled?
    end

    config.to_prepare do
      Pay::Stripe.setup if Pay::Stripe.enabled?
      Pay::Braintree.setup if Pay::Braintree.enabled?
      Pay::Paddle.setup if Pay::Paddle.enabled?

      if defined?(::Receipts::VERSION)
        if Pay::Engine.version_matches?(required: "~> 2", current: ::Receipts::VERSION)
          Pay::Charge.include Pay::Receipts
        else
          raise "[Pay] receipts gem must be version ~> 2"
        end
      end
    end

    # Determines if a gem version matches requirements
    # Used for verifying that dependencies are correct
    def version_matches?(current:, required:)
      Gem::Dependency.new("gem", required).match? "gem", current
    end
  end
end
