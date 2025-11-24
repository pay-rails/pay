require "test_helper"

class Pay::PaddleClassic::PaymentMethodTest < ActiveSupport::TestCase
  include PaymentMethodTests

  setup do
    @pay_customer = pay_customers(:paddle_classic)
  end
end
