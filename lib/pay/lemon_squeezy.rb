module Pay
  module LemonSqueezy
    class Error < Pay::Error
      delegate :message, to: :cause
    end

    module Webhooks
      autoload :Order, "pay/lemon_squeezy/webhooks/order"
      autoload :Subscription, "pay/lemon_squeezy/webhooks/subscription"
      autoload :SubscriptionPayment, "pay/lemon_squeezy/webhooks/subscription_payment"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:lemon_squeezy) && defined?(::LemonSqueezy)

      Pay::Engine.version_matches?(required: "~> 1.0", current: ::LemonSqueezy::VERSION) || (raise "[Pay] lemonsqueezy gem must be version ~> 1.0")
    end

    def self.setup
      ::LemonSqueezy.config.api_key = api_key
    end

    def self.api_key
      find_value_by_name(:lemon_squeezy, :api_key)
    end

    def self.store_id
      find_value_by_name(:lemon_squeezy, :store_id)
    end

    def self.signing_secret
      find_value_by_name(:lemon_squeezy, :signing_secret)
    end

    def self.passthrough(owner:, **options)
      owner.to_sgid.to_s
    end

    def self.owner_from_passthrough(passthrough)
      GlobalID::Locator.locate_signed passthrough
    rescue JSON::ParserError
      nil
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "lemon_squeezy.order_created", Pay::LemonSqueezy::Webhooks::Order.new
        events.subscribe "lemon_squeezy.subscription_created", Pay::LemonSqueezy::Webhooks::Subscription.new
        events.subscribe "lemon_squeezy.subscription_updated", Pay::LemonSqueezy::Webhooks::Subscription.new
        events.subscribe "lemon_squeezy.subscription_payment_refunded", Pay::LemonSqueezy::Webhooks::SubscriptionPayment.new
        events.subscribe "lemon_squeezy.subscription_payment_success", Pay::LemonSqueezy::Webhooks::SubscriptionPayment.new
      end
    end

    def self.construct_from_webhook_event(event)
      data = event["data"]
      case data
      when Array
        data.map do |object|
          construct_from_webhook_event(object)
        end
      when Hash
        type = {
          "orders" => ::LemonSqueezy::Order,
          "subscriptions" => ::LemonSqueezy::Subscription,
          "subscription-invoices" => ::LemonSqueezy::SubscriptionInvoice
        }.fetch(data["type"])

        type.new(data)
      end
    end

    # An Order may have subscriptions or be a one-time purchase
    def self.sync_order(order_id, object: nil)
      subscriptions = ::LemonSqueezy::Subscription.list(order_id: order_id).data
      subscriptions.each do |subscription|
        Pay::LemonSqueezy::Subscription.sync(subscription.id, object: subscription)
        ::LemonSqueezy::SubscriptionInvoice.list(subscription_id: subscription.id).data.each do |invoice|
          Pay::LemonSqueezy::Charge.sync_subscription_invoice(invoice.id, object: invoice)
        end
      end

      if subscriptions.empty?
        Pay::LemonSqueezy::Charge.sync_order(order_id, object: object)
      end
    end
  end
end
