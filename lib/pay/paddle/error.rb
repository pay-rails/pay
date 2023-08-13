module Pay
  module Paddle
    class Error < Pay::Error
      delegate :message, to: :cause
    end
  end
end
