module Pay
  module Stripe
    class Error < Pay::Error
      def message
        I18n.t("errors.stripe.#{result.code}", default: result.message)
      end
    end
  end
end
