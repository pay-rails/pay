module Pay
  module Lago
    autoload :Billable, "pay/lago/billable"
    autoload :Charge, "pay/lago/charge"
    autoload :Error, "pay/lago/error"
    autoload :PaymentMethod, "pay/lago/payment_method"
    autoload :Subscription, "pay/lago/subscription"
    autoload :Merchant, "pay/lago/merchant"

    module Webhooks
      autoload :CustomerPaymentProviderCreated, "pay/lago/webhooks/customer_payment_provider_created"
      autoload :InvoiceCreated, "pay/lago/webhooks/invoice_created"
      autoload :InvoiceDrafted, "pay/lago/webhooks/invoice_drafted"
      autoload :InvoiceOneOffCreated, "pay/lago/webhooks/invoice_one_off_created"
      autoload :InvoicePaymentStatusUpdated, "pay/lago/webhooks/invoice_payment_status_updated"
      autoload :SubscriptionStarted, "pay/lago/webhooks/subscription_started"
      autoload :SubscriptionTerminated, "pay/lago/webhooks/subscription_terminated"
    end

    extend Env

    class << self
      def enabled?
        return false unless Pay.enabled_processors.include?(:lago) && defined?(::Lago)
        true
      end

      def client
        @client ||= ::Lago::Api::Client.new(api_key: api_key, api_url: api_url)
      end

      def webhook_public_key
        @webhook_public_key ||= client.webhooks.public_key
      end

      def api_key
        find_value_by_name(:lago, :api_key)
      end

      def api_url
        find_value_by_name(:lago, :api_url)
      end

      def configure_webhooks
        Pay::Webhooks.configure do |events|
          events.subscribe "lago.customer.payment_provider_created", Pay::Lago::Webhooks::CustomerPaymentProviderCreated.new
          events.subscribe "lago.invoice.created", Pay::Lago::Webhooks::InvoiceCreated.new
          events.subscribe "lago.invoice.drafted", Pay::Lago::Webhooks::InvoiceDrafted.new
          events.subscribe "lago.invoice.one_off_created", Pay::Lago::Webhooks::InvoiceOneOffCreated.new
          events.subscribe "lago.invoice.payment_status_updated", Pay::Lago::Webhooks::InvoicePaymentStatusUpdated.new
          events.subscribe "lago.subscription.started", Pay::Lago::Webhooks::SubscriptionStarted.new
          events.subscribe "lago.subscription.terminated", Pay::Lago::Webhooks::SubscriptionTerminated.new
        end
      end

      # Helpers for working with Lago client
      def openstruct_to_h(ostruct)
        return ostruct.to_h.transform_values { |value| openstruct_to_h(value) } if ostruct.is_a?(OpenStruct) || ostruct.is_a?(Hash)
        return ostruct.map { |value| openstruct_to_h(value) } if ostruct.is_a?(Array)
        ostruct
      end
    end
  end
end
