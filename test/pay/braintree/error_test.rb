require "test_helper"

class Pay::Braintree::ErrorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "gob@bluth.com", processor: :braintree)
  end

  test "raising braintree failures keep the same message" do
    exception = assert_raises(Pay::Braintree::Error) { @user.charge(0) }
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

