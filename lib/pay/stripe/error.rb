module Pay
  module Stripe
    class Error < Pay::Error
      delegate :message, to: :cause
    end
  end
end
