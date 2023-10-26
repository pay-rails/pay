module Pay
  module PaddleBilling
    class Error < Pay::Error
      delegate :message, to: :cause
    end
  end
end
