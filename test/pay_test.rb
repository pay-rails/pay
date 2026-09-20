require "test_helper"

class Pay::Test < ActiveSupport::TestCase
  test "default automount_routes is true" do
    assert_equal true, Pay.automount_routes
  end

  test "default routes_path is /pay" do
    assert_equal "/pay", Pay.routes_path
  end

  test "parent_mailer config" do
    assert_equal "Pay::ApplicationMailer", Pay.parent_mailer
  end

  test "mailer config" do
    Pay.mailer = "Pay::ApplicationMailer"
    assert_equal Pay::ApplicationMailer, Pay.mailer

    Pay.mailer = "Pay::UserMailer"
    assert_equal Pay::UserMailer, Pay.mailer
  end

  test "mailer is resolved on every call so a reloaded class is picked up" do
    original = Pay.mailer
    reloaded = Class.new(original)
    String.any_instance.stubs(:constantize).returns(reloaded)

    assert_equal reloaded, Pay.mailer
  end

  {stripe: Pay::Stripe, braintree: Pay::Braintree, paddle_billing: Pay::PaddleBilling, paddle_classic: Pay::PaddleClassic, lemon_squeezy: Pay::LemonSqueezy}.each do |name, processor|
    test "can enable and disable the #{name} processor" do
      original = Pay.enabled_processors

      Pay.enabled_processors = []
      refute processor.enabled?

      Pay.enabled_processors = [name]
      assert processor.enabled?
    ensure
      Pay.enabled_processors = original
    end
  end

  test "can disable all emails with a boolean" do
    original_send_email_value = Pay.send_emails

    Pay.emails.keys.each do |mail_action|
      Pay.emails.stub mail_action, true do
        assert Pay.send_email?(mail_action)
      end
    end

    Pay.send_emails = false

    Pay.emails.keys.each do |mail_action|
      refute Pay.send_email?(mail_action)
    end
  ensure
    Pay.send_emails = original_send_email_value
  end

  test "can disable all emails with a lambda" do
    original_send_email_value = Pay.send_emails

    Pay.emails.keys.each do |mail_action|
      Pay.emails.stub mail_action, true do
        assert Pay.send_email?(mail_action)
      end
    end

    Pay.send_emails = -> { false }

    Pay.emails.keys.each do |mail_action|
      refute Pay.send_email?(mail_action)
    end
  ensure
    Pay.send_emails = original_send_email_value
  end

  test "can configure email options with a boolean" do
    Pay.emails.stub :subscription_renewing, true do
      assert Pay.send_email?(:subscription_renewing)
      assert Pay.send_email?(:subscription_renewing, "dummy_subscription")
    end

    Pay.emails.stub :subscription_renewing, false do
      refute Pay.send_email?(:subscription_renewing)
    end
  end

  test "can configure email options with a lambda" do
    pay_subscription = pay_subscriptions(:fake)

    custom_lambda = ->(subscription) { assert_equal pay_subscription, subscription }

    Pay.emails.stub :subscription_renewing, -> { custom_lambda } do
      Pay.send_email?(:subscription_renewing, pay_subscription)
    end
  end

  test "can retrieve Pay::UserMail as default mailer" do
    assert_equal Pay.mailer, Pay::UserMailer
  end

  test "can configure mailer and retrieve correct class" do
    Pay.mailer = "ApplicationMailer"
    assert_equal Pay.mailer, ApplicationMailer
  ensure
    Pay.mailer = "Pay::UserMailer" # clean up for other tests
  end

  test "can configure mail_arguments" do
    old_mail_arguments = Pay.mail_arguments
    Pay.mail_arguments = -> { {to: "to", cc: "cc"} }
    assert_equal({to: "to", cc: "cc"}, Pay.mail_arguments.call)
  ensure
    Pay.mail_arguments = old_mail_arguments
  end

  test "can configure mail_to" do
    old_mail_to = Pay.mail_to
    Pay.mail_to = -> { "user@example.org" }
    assert_equal "user@example.org", Pay.mail_to.call
  ensure
    Pay.mail_to = old_mail_to
  end
end
