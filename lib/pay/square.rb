module Pay
  module Square
    # Unlike Stripe Connect (one platform key + a stripe_account header), Square issues a
    # distinct OAuth access token per merchant, so the processor builds a Square::Client
    # per operation from a token supplied by access_token_provider.
    class Error < Pay::Error
    end

    module Webhooks
      autoload :Payment, "pay/webhooks/square/payment"
      autoload :Refund, "pay/webhooks/square/refund"
      autoload :Card, "pay/webhooks/square/card"
      autoload :Customer, "pay/webhooks/square/customer"
    end

    extend Env

    REQUIRED_VERSION = "~> 44"

    # A callable accepting (pay_customer, force_refresh = false) that returns a fresh
    # per-merchant OAuth access token. force_refresh is set true on the retry after a 401.
    mattr_accessor :access_token_provider, default: nil

    mattr_accessor :model_names, default: Set.new

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:square) && defined?(::Square)

      # square.rb does not autoload Square::VERSION on `require "square"`.
      current = ::Gem.loaded_specs["square.rb"]&.version&.to_s
      return true if current.nil?
      Pay::Engine.version_matches?(required: REQUIRED_VERSION, current: current) || (raise "[Pay] square.rb gem must be version #{REQUIRED_VERSION}")
    end

    # No global API key: Square authenticates per-merchant via access_token_provider.
    def self.setup
    end

    def self.environment
      find_value_by_name(:square, :environment).presence || "production"
    end

    def self.base_url
      (environment.to_s == "sandbox") ? ::Square::Environment::SANDBOX : ::Square::Environment::PRODUCTION
    end

    def self.signing_secret
      find_value_by_name(:square, :signing_secret)
    end

    # Square's HMAC covers (notification_url + body), so this must match the URL registered
    # with Square; behind a proxy request.original_url may not.
    def self.webhook_notification_url
      find_value_by_name(:square, :webhook_notification_url)
    end

    def self.access_token(pay_customer, force_refresh: false)
      unless access_token_provider.respond_to?(:call)
        raise Pay::Square::Error, "Pay::Square.access_token_provider is not configured. Set it to a callable that returns a fresh Square OAuth access token for a Pay::Customer."
      end

      token = if access_token_provider.arity == 1 || access_token_provider.arity.zero?
        access_token_provider.call(pay_customer)
      else
        access_token_provider.call(pay_customer, force_refresh)
      end

      raise Pay::Square::Error, "Pay::Square.access_token_provider returned a blank token for pay_customer #{pay_customer&.id}" if token.blank?
      token
    end

    def self.client(pay_customer, force_refresh: false)
      ::Square::Client.new(base_url: base_url, token: access_token(pay_customer, force_refresh: force_refresh))
    end

    # Retries ONCE with a force-refreshed token on a 401 and maps Square errors to
    # Pay::Square::Error. Callers MUST build any idempotency_key outside this block so the
    # retry reuses the same key and cannot double-charge.
    def self.with_client(pay_customer)
      attempts = 0
      begin
        attempts += 1
        yield client(pay_customer, force_refresh: attempts > 1)
      rescue ::Square::Errors::UnauthorizedError => e
        if attempts < 2
          Rails.logger.info { "[Pay::Square] access token rejected (401) for pay_customer #{pay_customer&.id}; forcing refresh and retrying" }
          retry
        end
        raise Pay::Square::Error, e
      rescue ::Square::Errors::ApiError => e
        raise Pay::Square::Error, e
      end
    end

    def self.construct_from_webhook_event(event)
      case event
      when Hash
        ActiveSupport::InheritableOptions.new(event.map { |key, value| [key.to_sym, construct_from_webhook_event(value)] }.to_h)
      when Array
        event.map { |value| construct_from_webhook_event(value) }
      else
        event
      end
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "square.payment.created", Pay::Square::Webhooks::Payment.new
        events.subscribe "square.payment.updated", Pay::Square::Webhooks::Payment.new
        events.subscribe "square.refund.created", Pay::Square::Webhooks::Refund.new
        events.subscribe "square.refund.updated", Pay::Square::Webhooks::Refund.new
        events.subscribe "square.card.created", Pay::Square::Webhooks::Card.new
        events.subscribe "square.card.updated", Pay::Square::Webhooks::Card.new
        events.subscribe "square.card.disabled", Pay::Square::Webhooks::Card.new
        events.subscribe "square.customer.created", Pay::Square::Webhooks::Customer.new
        events.subscribe "square.customer.updated", Pay::Square::Webhooks::Customer.new
        events.subscribe "square.customer.deleted", Pay::Square::Webhooks::Customer.new
      end
    end
  end
end
