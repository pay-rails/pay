require "test_helper"

class Pay::Stripe::ErrorTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: nil)
    @pay_customer.payment_methods.destroy_all
  end

  test "re-raised stripe exceptions keep the same message" do
    exception = assert_raises(Pay::Stripe::Error) { @pay_customer.charge(0) }
    assert_match "The amount must be greater than or equal to", exception.message
    assert_equal ::Stripe::InvalidRequestError, exception.cause.class
  end
end
