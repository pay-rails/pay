require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = User.new(email: "john@example.org", extra_billing_info: "extra billing info")
    @charge = @user.charges.new(amount: 100, created_at: Time.zone.now)
  end

  test "receipt" do
    email = Pay::UserMailer.with(billable: @user, charge: @charge).receipt

    assert_equal [@user.email], email.to
    assert_equal I18n.t("pay.user_mailer.receipt.subject"), email.subject
  end

  test "attaches refunds to receipt" do
    filename = "receipt.pdf"

    receipt = mock("receipt")
    receipt.stubs(:render).returns("render content")
    receipt.stubs(:length).returns(1024)

    @charge.stubs(:filename).returns(filename)
    @charge.stubs(:receipt).returns(receipt)

    email = Pay::UserMailer.with(billable: @user, charge: @charge).receipt

    assert_equal filename, email.attachments.first.filename
  end

  test "refund" do
    email = Pay::UserMailer.with(billable: @user, charge: @charge).refund

    assert_equal [@user.email], email.to
    assert_equal I18n.t("pay.user_mailer.refund.subject"), email.subject
  end

  test "subscription_renewing" do
    time = Time.current
    email = Pay::UserMailer.with(billable: @user, subscription: Pay::Subscription.new, date: time).subscription_renewing

    assert_equal [@user.email], email.to
    assert_equal I18n.t("pay.user_mailer.subscription_renewing.subject"), email.subject
    assert_includes email.body.decoded, I18n.l(time.to_date, format: :long)
  end

  test "payment_action_required" do
    email = Pay::UserMailer.with(billable: @user, payment_intent_id: "x", subscription: Pay::Subscription.new).payment_action_required

    assert_equal [@user.email], email.to
    assert_equal I18n.t("pay.user_mailer.payment_action_required.subject"), email.subject
    assert_includes email.body.decoded, Pay::Engine.instance.routes.url_helpers.payment_path("x")
  end
end
