module Pay
  # https://avdi.codes/exception-causes-in-ruby-2-1/
  class Error < StandardError
  end

  # Raised when a payment processor cannot perform an operation, such as pausing a Braintree subscription
  class NotSupportedError < Error
  end

  class PaymentError < Error
    attr_reader :payment

    def initialize(payment)
      @payment = payment
    end
  end

  class ActionRequired < PaymentError
    def message
      I18n.t("pay.errors.action_required")
    end
  end

  class InvalidPaymentMethod < PaymentError
    def message
      I18n.t("pay.errors.invalid_payment")
    end
  end
end
