require "test_helper"

class Pay::Stripe::ConnectTest < ActiveSupport::TestCase
  setup do
    @stripe_account_id = "acct_1ISuLNQK2ZHS99Rk"
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, stripe_account: @stripe_account_id, card_token: "pm_card_visa")

    # Create Stripe customer
    @user.customer
  end

  test "connect account customer" do
    assert_equal ::Stripe::Customer, @user.customer.class
  end

  test "connect customer is not on parent account" do
    assert_raises Stripe::InvalidRequestError do
      ::Stripe::Customer.retrieve(@user.processor_id)
    end
  end

  test "connect charge" do
    pay_charge = @user.charge(10_00)
    assert_equal @stripe_account_id, pay_charge.stripe_account
  end

  test "connect subscription" do
    pay_subscription = @user.subscribe(plan: "price_1ISuPKQK2ZHS99Rkrxy6GwbM")
    assert_equal @stripe_account_id, pay_subscription.stripe_account
  end
end
