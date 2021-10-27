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

    config.to_prepare do
      Pay::Stripe.setup if defined? ::Stripe && Pay.enabled_processors&.include?(:stripe)
      Pay::Braintree.setup if defined? ::Braintree && Pay.enabled_processors&.include?(:braintree)
      Pay::Paddle.setup if defined? ::PaddlePay && Pay.enabled_processors&.include?(:paddle)

      Pay::Charge.include Pay::Receipts if defined? ::Receipts::Receipt
    end
  end
end
