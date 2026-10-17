# frozen_string_literal: true

module Pay
  class Engine < ::Rails::Engine
    engine_name "pay"

    # Rails main runs this from Rails::Application#ractorize! before it shares the application with Ractors
    ActiveSupport.on_load(:before_ractorize) { Pay.make_shareable! }

    initializer "pay.processors" do |app|
      if Pay.automount_routes
        # Rails runs the block with instance_exec on the route mapper, so its self is irrelevant. Left as it is,
        # the self would be this engine instance, which stops Rails from sharing the application with Ractors.
        mount_pay = proc { mount Pay::Engine, at: Pay.routes_path, as: "pay" }
        mount_pay = ::Ractor.shareable_proc(self: nil, &mount_pay) if defined?(::Ractor) && ::Ractor.respond_to?(:shareable_proc)
        app.routes.append(&mount_pay)
      end

      # Include the pay attributes for ActiveRecord models
      ActiveSupport.on_load(:active_record) do
        include Pay::Attributes
      end
    end

    initializer "pay.deprecator" do |app|
      app.deprecators[:pay] = Pay.deprecator if app.respond_to?(:deprecators)
    end

    RECEIPTS_VERSION = [">= 2", "< 4"].freeze

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
    def self.version_matches?(current:, required:)
      Gem::Dependency.new("gem", required).match? "gem", current
    end
  end
end
