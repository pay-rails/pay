module Pay
  module Paddle
    class Error < Pay::Error
      def message
        I18n.t("errors.paddle.#{result.code}", default: result.message)
      end
    end
  end
end
