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

  module Braintree
    class Error < Error
      def message
        result.message
      end
    end

    class AuthorizationError < Braintree::Error
      def message
        I18n.t("errors.braintree.authorization")
      end
    end
  end

  module Stripe
    class Error < Error
      def message
        I18n.t("errors.stripe.#{result.code}", default: result.message)
      end
    end
  end

  module Paddle
    class Error < Error
      def message
        I18n.t("errors.paddle.#{result.code}", default: result.message)
      end
    end
  end

  class BraintreeError < Braintree::Error
    def message
      ActiveSupport::Deprecation.warn("Pay::BraintreeError is deprecated. Instead, use `Pay::Braintree::Error`.")
      super
    end
  end

  class BraintreeAuthorizationError < BraintreeError
    def message
      ActiveSupport::Deprecation.warn("Pay::BraintreeAuthorizationError is deprecated. Instead, use `Pay::Braintree::AuthorizationError`.")
      I18n.t("errors.braintree.authorization")
    end
  end
end
