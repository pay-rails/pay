require "test_helper"

class Pay::Stripe::CheckoutTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe)

    # Create Stripe customer
    @user.customer
  end

  test "checkout setup session" do
    session = @user.payment_processor.checkout(mode: "setup")
    assert_equal "setup", session.mode
  end

  test "checkout payment session" do
    session = @user.payment_processor.checkout(mode: "payment", line_items: "price_1ILVZaKXBGcbgpbZQ26kgXWG")
    assert_equal "payment", session.mode
  end

  test "checkout subscription session" do
    session = @user.payment_processor.checkout(mode: "subscription", line_items: "default")
    assert_equal "subscription", session.mode
  end

  test "billing portal session" do
    session = @user.payment_processor.billing_portal
    assert_not_nil session.url
  end
end
