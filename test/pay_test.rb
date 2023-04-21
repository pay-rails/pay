require "test_helper"

class Pay::Test < ActiveSupport::TestCase
  test "truth" do
    assert_kind_of Module, Pay
  end

  test "default automount_routes is true" do
    assert Pay.automount_routes, true
  end

  test "default routes_path is /pay" do
    assert Pay.routes_path, "/pay"
  end

  test "can set business name" do
    assert Pay.respond_to?(:business_name)
    assert Pay.respond_to?(:business_name=)
  end

  test "can set business address" do
    assert Pay.respond_to?(:business_address)
    assert Pay.respond_to?(:business_address=)
  end

  test "can set application name" do
    assert Pay.respond_to?(:application_name)
    assert Pay.respond_to?(:application_name=)
  end

  test "can set support email" do
    assert Pay.respond_to?(:support_email)
    assert Pay.respond_to?(:support_email=)
  end

  test "can set default product name" do
    assert Pay.respond_to?(:default_product_name)
    assert Pay.respond_to?(:default_product_name=)
  end

  test "can set default plan name" do
    assert Pay.respond_to?(:default_plan_name)
    assert Pay.respond_to?(:default_plan_name=)
  end

  test "can configure enabled_processors" do
    assert Pay.respond_to?(:enabled_processors)
    assert Pay.respond_to?(:enabled_processors=)
  end

  test "parent_mailer config" do
    assert Pay.respond_to?(:parent_mailer=)
    assert Pay.respond_to?(:parent_mailer)
    assert_equal "Pay::ApplicationMailer", Pay.parent_mailer
  end

  test "mailer config" do
    assert Pay.respond_to?(:mailer=)
    assert Pay.respond_to?(:mailer)

    Pay.mailer = "Pay::ApplicationMailer"
    assert_equal Pay::ApplicationMailer, Pay.mailer

    Pay.mailer = "Pay::UserMailer"
    assert_equal Pay::UserMailer, Pay.mailer
  end

  test "can enable and disable the stripe processor" do
    original = Pay.enabled_processors

    Pay.enabled_processors = []
    refute Pay::Stripe.enabled?

    Pay.enabled_processors = [:stripe]
    assert Pay::Stripe.enabled?

    Pay.enabled_processors = original
  end

  test "can enable and disable the braintree processor" do
    original = Pay.enabled_processors

    Pay.enabled_processors = []
    refute Pay::Braintree.enabled?

    Pay.enabled_processors = [:braintree]
    assert Pay::Braintree.enabled?

    Pay.enabled_processors = original
  end

  test "can enable and disable the paddle processor" do
    original = Pay.enabled_processors

    Pay.enabled_processors = []
    refute Pay::Paddle.enabled?

    Pay.enabled_processors = [:paddle]
    assert Pay::Paddle.enabled?

    Pay.enabled_processors = original
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
    assert_equal(Pay.mailer, Pay::UserMailer)
  end

  test "can configure mailer and retrieve correct class" do
    Pay.mailer = "ApplicationMailer"
    assert_equal(Pay.mailer, ApplicationMailer)
  ensure
    Pay.mailer = "Pay::UserMailer" # clean up for other tests
  end

  test "can configure mail_arguments" do
    old_mail_arguments = Pay.mail_arguments
    Pay.mail_arguments = ->(mailer, params) { {to: "to", cc: "cc"} }
    assert_equal({to: "to", cc: "cc"}, Pay.mail_arguments.call("pay/receipt", {}))
  ensure
    Pay.mail_arguments = old_mail_arguments
  end

  test "can configure mail_to" do
    old_mail_to = Pay.mail_to
    Pay.mail_to = ->(mailer, params) { "user@example.org" }
    assert_equal "user@example.org", Pay.mail_to.call("pay/receipt", {})
  ensure
    Pay.mail_to = old_mail_to
  end
end
