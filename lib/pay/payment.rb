module Pay
  class Payment
    attr_reader :intent

    delegate :id, :amount, :client_secret, :currency, :customer, :status, :confirm, to: :intent

    def self.from_id(id)
      intent = id.start_with?("seti_") ? ::Stripe::SetupIntent.retrieve(id) : ::Stripe::PaymentIntent.retrieve(id)
      new(intent)
    end

    def initialize(intent)
      @intent = intent
    end

    def requires_payment_method?
      status == "requires_payment_method"
    end

    def requires_action?
      status == "requires_action"
    end

    def canceled?
      status == "canceled"
    end

    def cancelled?
      canceled?
    end

    def succeeded?
      status == "succeeded"
    end

    def payment_intent?
      intent.is_a?(::Stripe::PaymentIntent)
    end

    def setup_intent?
      intent.is_a?(::Stripe::SetupIntent)
    end

    def amount_with_currency
      Pay::Currency.format(amount, currency: currency)
    end

    def validate
      if requires_payment_method?
        raise Pay::InvalidPaymentMethod.new(self)
      elsif requires_action?
        raise Pay::ActionRequired.new(self)
      end
    end
  end
end
