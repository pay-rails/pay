require "test_helper"

class Pay::Stripe::ConnectTest < ActiveSupport::TestCase
  setup do
    @stripe_account_id = "acct_1ISuLNQK2ZHS99Rk"
    @user = User.create!(email: "gob@bluth.com")
    @pay_customer = @user.set_payment_processor :stripe, stripe_account: @stripe_account_id
    @pay_customer.update_payment_method "pm_card_visa"
  end

  test "connect account customer" do
    assert_equal ::Stripe::Customer, @user.payment_processor.api_record.class
  end

  test "connect customer is not on parent account" do
    assert_raises Stripe::InvalidRequestError do
      ::Stripe::Customer.retrieve(@user.payment_processor.processor_id)
    end
  end

  test "connect direct charge" do
    pay_charge = @user.payment_processor.charge(10_00)
    assert_equal @stripe_account_id, pay_charge.stripe_account
  end

  test "connect destination charge" do
    @user = User.create!(email: "gob@bluth.com")
    @user.set_payment_processor :stripe
    @user.payment_processor.update_payment_method "pm_card_visa"

    pay_charge = @user.payment_processor.charge(
      10_00,
      application_fee_amount: 1_23,
      transfer_data: {destination: @stripe_account_id}
    )

    assert_equal @stripe_account_id, pay_charge.api_record.destination
  end

  test "connect direct subscription" do
    pay_subscription = @user.payment_processor.subscribe(plan: "price_1ISuPKQK2ZHS99Rkrxy6GwbM")
    assert_equal @stripe_account_id, pay_subscription.stripe_account
  end

  test "connect account" do
    account = Account.create
    account.set_merchant_processor(:stripe)
    account.merchant_processor.update(processor_id: "acct_1IStbKQOsIOBQfn0")
    assert_equal ::Stripe::Account, account.merchant_processor.account.class
  end

  test "connect transfer" do
    @user.payment_processor.charge(10_00, transfer_group: "12345")
    account = Account.create
    account.set_merchant_processor(:stripe)
    account.merchant_processor.update(processor_id: "acct_1IStbKQOsIOBQfn0")
    transfer = account.merchant_processor.transfer(amount: 7_00, transfer_group: "12345")
    assert_equal 7_00, transfer.amount
    assert_equal "acct_1IStbKQOsIOBQfn0", transfer.destination
  end
end
