require "test_helper"

class Pay::FakeProcessor::PaymentMethodTest < ActiveSupport::TestCase
  include PaymentMethodTests

  setup do
    @pay_customer = pay_customers(:fake)
  end
end
