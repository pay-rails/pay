require "test_helper"

class Pay::PaddleBilling::PaymentMethodTest < ActiveSupport::TestCase
  include PaymentMethodTests

  setup do
    @pay_customer = pay_customers(:paddle_billing)
  end
end
