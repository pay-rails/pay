module Pay
  module Paddle
    class Error < Pay::Error
      def message
        I18n.t("errors.paddle.#{cause.code}", default: cause.message)
      end
    end
  end
end
