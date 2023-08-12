module Pay
  module PaddleClassic
    class Error < Pay::Error
      delegate :message, to: :cause
    end
  end
end
