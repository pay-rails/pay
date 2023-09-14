module Pay
  module Lago
    class Error < Pay::Error
      def message
        cause.try(:message) || to_s
      end
    end
  end
end
