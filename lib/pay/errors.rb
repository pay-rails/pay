module Pay
  # https://avdi.codes/exception-causes-in-ruby-2-1/
  class Error < StandardError
  end

  class PaymentError < StandardError
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
