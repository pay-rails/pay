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

    initializer "pay.webhooks" do
      Pay::Stripe.configure_webhooks if defined?(::Stripe)
      Pay::Braintree.configure_webhooks if defined?(::Braintree)
      Pay::Paddle.configure_webhooks if defined?(::PaddlePay)
    end

    config.to_prepare do
      if defined?(::Stripe) && version_matches?(required: "~> 5", current: ::Stripe::VERSION)
        Pay::Stripe.setup
      else
        raise "[Pay] stripe gem must be version ~> 5"
      end

      if defined?(::Braintree) && version_matches?(required: "~> 4", current: ::Braintree::VERSION)
        Pay::Braintree.setup
      else
        raise "[Pay] braintree gem must be version ~> 4"
      end

      if defined?(::PaddlePay) && version_matches?(required: "~> 0.2", current: ::PaddlePay::VERSION)
        Pay::Paddle.setup
      else
        raise "[Pay] paddle_pay gem must be version ~> 0.2"
      end


      if defined?(::Receipts::VERSION) && version_matches?(required: "~> 2", current: ::Receipts::VERSION)
        Pay::Charge.include Pay::Receipts
      else
        raise "[Pay] receipts gem must be version ~> 2"
      end
    end

    # Determines if a gem version matches requirements
    # Used for verifying that dependencies are correct
    def version_matches?(current:, required:)
      Gem::Dependency.new("gem", required).match? "gem", current
    end
  end
end
