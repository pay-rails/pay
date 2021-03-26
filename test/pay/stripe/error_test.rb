require "test_helper"

class Pay::Stripe::ErrorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe)
  end

  test "re-raised exceptions keep the same message" do
    exception = assert_raises(Pay::Stripe::Error) { @user.charge(0) }
    assert_match "This value must be greater than or equal to 1.", exception.to_s
    assert_equal ::Stripe::InvalidRequestError, exception.cause.class
  end
end
