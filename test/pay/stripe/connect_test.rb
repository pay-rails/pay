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

  test "connect direct charge" do
    pay_charge = @user.charge(10_00)
    assert_equal @stripe_account_id, pay_charge.stripe_account
  end

  test "connect destination charge" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, card_token: "pm_card_visa")

    pay_charge = @user.charge(
      10_00,
      application_fee_amount: 1_23,
      transfer_data: {destination: @stripe_account_id}
    )

    assert_equal @stripe_account_id, pay_charge.processor_charge.destination
  end

  test "connect direct subscription" do
    pay_subscription = @user.subscribe(plan: "price_1ISuPKQK2ZHS99Rkrxy6GwbM")
    assert_equal @stripe_account_id, pay_subscription.stripe_account
  end

  test "connect account" do
    assert_equal ::Stripe::Account, Pay::Stripe.account("acct_1IStbKQOsIOBQfn0").class
  end

  test "connect transfer" do
    @user.charge(10_00, transfer_group: "12345")
    transfer = Pay::Stripe.transfer(7_00, destination: "acct_1IStbKQOsIOBQfn0", transfer_group: "12345")
    assert_equal 7_00, transfer.amount
    assert_equal "acct_1IStbKQOsIOBQfn0", transfer.destination
  end
end
