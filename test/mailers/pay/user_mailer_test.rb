require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  test "receipt" do
    user = User.new(email: 'john@example.org')
    user.stubs(:extra_billing_info?).returns(true)
    user.stubs(:extra_billing_info).returns('extra billing info')
    charge = Pay::Charge.new(amount: 100, owner: user)
    receipt = mock('receipt')
    receipt.stubs(:render).returns('render content')
    charge.stubs(:filename).returns('file.name')
    charge.stubs(:receipt).returns(receipt)
    email = Pay::UserMailer.receipt(user, charge)

    assert_equal ['john@example.org'], email.to
    assert_equal 'Payment receipt', email.subject

    # Configurable subject
    new_subject = 'My email receipt subject'
    Pay.email_receipt_subject = new_subject
    email = Pay::UserMailer.receipt(user, charge)
    assert_equal new_subject, email.subject
  end

  test "refund" do
    user = User.new(email: 'john@example.org')
    user.stubs(:extra_billing_info?).returns(true)
    user.stubs(:extra_billing_info).returns('extra billing info')
    charge = Pay::Charge.new(amount: 100, owner: user)
    receipt = mock('receipt')
    receipt.stubs(:render).returns('render content')
    charge.stubs(:filename).returns('file.name')
    charge.stubs(:receipt).returns(receipt)
    email = Pay::UserMailer.refund(user, charge)

    assert_equal ['john@example.org'], email.to
    assert_equal 'Payment refunded', email.subject

    # Configurable subject
    new_subject = 'My email refund subject'
    Pay.email_refund_subject = new_subject
    email = Pay::UserMailer.refund(user, charge)
    assert_equal new_subject, email.subject
  end

  test "renewal" do
    user = User.new(email: 'john@example.org')
    user.stubs(:extra_billing_info?).returns(true)
    user.stubs(:extra_billing_info).returns('extra billing info')
    charge = Pay::Charge.new(amount: 100, owner: user)
    receipt = mock('receipt')
    receipt.stubs(:render).returns('render content')
    charge.stubs(:filename).returns('file.name')
    charge.stubs(:receipt).returns(receipt)
    email = Pay::UserMailer.subscription_renewing(user, charge)

    assert_equal ['john@example.org'], email.to
    assert_equal 'Your upcoming subscription renewal', email.subject

    # Configurable subject
    new_subject = 'My email renewal subject'
    Pay.email_renewing_subject = new_subject
    email = Pay::UserMailer.subscription_renewing(user, charge)
    assert_equal new_subject, email.subject
  end
end
