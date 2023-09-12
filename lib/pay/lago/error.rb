module Pay
  module Lago
    class Error < Pay::Error
      delegate :message, to: :cause
    end
  end
end
