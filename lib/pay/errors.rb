module Pay
  class Error < StandardError
    attr_reader :result

    def initialize(result = nil)
      @result = result
    end
  end

  class PaymentError < StandardError
    attr_reader :payment

    def initialize(payment)
      @payment = payment
    end
  end

  class ActionRequired < PaymentError
    def message
      I18n.t("errors.action_required")
    end
  end

  class InvalidPaymentMethod < PaymentError
    def message
      I18n.t("errors.invalid_payment")
    end
  end
end
