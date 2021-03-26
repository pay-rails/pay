module Pay
  module Stripe
    class Error < Pay::Error
      def message
        I18n.t("errors.stripe.#{cause.code}", default: cause.message)
      end
    end
  end
end
