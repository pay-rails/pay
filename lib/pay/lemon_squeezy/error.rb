module Pay
  module LemonSqueezy
    class Error < Pay::Error
      delegate :message, to: :cause
    end
  end
end
