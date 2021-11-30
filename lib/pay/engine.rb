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
      Pay::Stripe.setup if defined? ::Stripe
      Pay::Braintree.setup if defined? ::Braintree
      Pay::Paddle.setup if defined? ::PaddlePay

      if Pay.generate_receipts
        Pay::Charge.include Pay::Receipts
      end
    end
  end
end
