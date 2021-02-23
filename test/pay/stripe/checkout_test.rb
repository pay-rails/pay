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

  test "raises an error with empty default_url_options" do
    # This should raise:
    # ArgumentError: Missing host to link to! Please provide the :host parameter, set default_url_options[:host], or set :only_path to true

    Rails.application.config.action_mailer.stub :default_url_options, nil do
      assert_raises ArgumentError do
        @user.payment_processor.checkout(mode: "setup")
      end
    end
  end
end
