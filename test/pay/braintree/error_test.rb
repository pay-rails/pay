require "test_helper"

class Pay::Braintree::ErrorTest < ActiveSupport::TestCase
  test "raising braintree failures keep the same message" do
    pay_customer = pay_customers(:braintree)
    pay_customer.update(processor_id: nil)
    exception = assert_raises(Pay::Braintree::Error) { pay_customer.charge(0) }
    assert_match "Amount must be greater than zero.", exception.to_s
    assert_equal ::Braintree::ErrorResult, exception.cause.class
  end

  test "re-raising braintree exceptions keep the same message" do
    exception = assert_raises(Pay::Braintree::Error) {
      begin
        raise ::Braintree::AuthorizationError, "Oh no!"
      rescue ::Braintree::AuthorizationError => e
        raise Pay::Braintree::Error, e
      end
    }
    assert_match "Oh no!", exception.to_s
    assert_equal ::Braintree::AuthorizationError, exception.cause.class
  end
end
