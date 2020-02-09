require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = User.new(email: "john@example.org", extra_billing_info: "extra billing info")
    @charge = @user.charges.new(amount: 100, created_at: Time.zone.now)
  end

  test "receipt" do
    email = Pay::UserMailer.receipt(@user, @charge)

    assert_equal [@user.email], email.to
    assert_equal Pay.email_receipt_subject, email.subject
  end

  test "attaches refunds to receipt" do
    filename = "receipt.pdf"

    receipt = mock("receipt")
    receipt.stubs(:render).returns("render content")
    receipt.stubs(:length).returns(1024)

    @charge.stubs(:filename).returns(filename)
    @charge.stubs(:receipt).returns(receipt)

    email = Pay::UserMailer.receipt(@user, @charge)

    assert_equal filename, email.attachments.first.filename
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
