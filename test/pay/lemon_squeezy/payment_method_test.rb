require "test_helper"

class Pay::LemonSqueezy::PaymentMethodTest < ActiveSupport::TestCase
  include PaymentMethodTests

  setup do
    @pay_customer = pay_customers(:lemon_squeezy)
  end
end
