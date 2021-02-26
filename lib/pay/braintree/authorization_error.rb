module Pay
  module Braintree
    class AuthorizationError < Braintree::Error
      def message
        I18n.t("errors.braintree.authorization")
      end
    end
  end
end
