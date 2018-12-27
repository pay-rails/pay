require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = User.new(email: 'john@example.org', extra_billing_info: 'extra billing info')

    receipt = mock('receipt')
    receipt.stubs(:render).returns('render content')

    @charge = Pay::Charge.new(amount: 100, owner: @user)
    @charge.stubs(:filename).returns('file.name')
    @charge.stubs(:receipt).returns(receipt)
  end

  test "receipt" do
    email = Pay::UserMailer.receipt(@user, @charge)

    assert_equal [@user.email], email.to
    assert_equal Pay.email_receipt_subject, email.subject
  end

  test "refund" do
    email = Pay::UserMailer.refund(@user, @charge)

    assert_equal [@user.email], email.to
    assert_equal Pay.email_refund_subject, email.subject
  end

  test "renewal" do
    email = Pay::UserMailer.subscription_renewing(@user, @charge)

    assert_equal [@user.email], email.to
    assert_equal Pay.email_renewing_subject, email.subject
  end
end
