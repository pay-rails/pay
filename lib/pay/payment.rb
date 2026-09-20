module Pay
  class Payment
    # The Stripe Connect account the intent lives on, if any. Needed to look the intent up again
    # and to initialize Stripe.js on the SCA confirmation page.
    attr_reader :intent, :stripe_account

    delegate :id, :amount, :client_secret, :currency, :customer, :status, :confirm, to: :intent

    def self.from_id(id, stripe_account: nil)
      options = {stripe_account: stripe_account}.compact
      intent = id.start_with?("seti_") ? ::Stripe::SetupIntent.retrieve(id, options) : ::Stripe::PaymentIntent.retrieve(id, options)
      new(intent, stripe_account: stripe_account)
    end

    def initialize(intent, stripe_account: nil)
      @intent = intent
      @stripe_account = stripe_account
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

    def succeeded?
      status == "succeeded"
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
