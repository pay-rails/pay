require "test_helper"

# Pay.make_shareable! freezes the configuration for the rest of the process, so every test here runs it in the
# forked child that in_ractor creates, never in the test process itself.
class Pay::MakeShareableTest < ActiveSupport::TestCase
  # Reading a class_attribute from a Ractor also needs Rails main, which defines its readers without closures
  RAILS_MAIN = Rails.gem_version >= Gem::Version.new("8.2.0.alpha")

  test "configuration can be read from a Ractor" do
    result = in_ractor(prepare: -> { Pay.make_shareable! }) do
      [
        Pay.default_product_name,
        Pay.application_name,
        Pay.enabled_processors.include?(:stripe),
        Pay.send_email?(:receipt),
        Pay.support_email.address,
        Pay.automount_routes,
        Pay.mailer.name
      ]
    end

    assert_equal ["default", "My App", true, true, "support@example.org", true, "Pay::UserMailer"], result
  end

  test "callable options defined outside Pay can be called from a Ractor" do
    prepare = lambda do
      # Defined in a test method, so their self is the test case, which is no more shareable than an initializer's main object
      Pay.send_emails = ->(*) { true }
      Pay.emails.subscription_renewing = ->(pay_subscription, price) { price == "year" }
      Pay.mail_to = -> { greeting }
      Pay.make_shareable!
    end

    result = in_ractor(prepare: prepare) do
      mailer = Object.new
      def mailer.greeting
        "hello"
      end

      [
        Pay.send_email?(:subscription_renewing, nil, "year"),
        Pay.send_email?(:subscription_renewing, nil, "month"),
        mailer.instance_exec(&Pay.mail_to)
      ]
    end

    assert_equal [true, false, "hello"], result
  end

  test "processor credentials are resolved before sharing and can be read from a Ractor" do
    result = in_ractor(prepare: -> { Pay.make_shareable! }) do
      [
        Pay::Stripe.private_key,
        Pay::Stripe.signing_secret,
        Pay::Stripe.webhook_receive_test_events,
        Pay::Braintree.merchant_id,
        Pay::PaddleBilling.environment,
        Pay::PaddleClassic.vendor_id,
        Pay::LemonSqueezy.api_key
      ]
    end

    assert_equal ["sk_test_fake", "whsec_x", true, "zyfwpztymjqdcc5g", "sandbox", "paddle_classic_vendor_id", nil], result
  end

  test "each Ractor builds its own Paddle Classic client" do
    result = in_ractor(prepare: -> { Pay.make_shareable! }) do
      client = Pay::PaddleClassic.client
      [client.class.name, client.equal?(Pay::PaddleClassic.client)]
    end

    assert_equal ["Paddle::Classic::Client", true], result
  end

  test "constants, currencies, the webhooks delegator and the Stripe model list can be read from a Ractor" do
    prepare = lambda do
      [Pay::Stripe::Charge, Pay::Currency, User].each(&:name) # Loaded here because a Ractor can't autoload
      Pay.make_shareable!
    end

    result = in_ractor(prepare: prepare) do
      [
        Pay.sync({}),
        Pay::Stripe::Charge::EXPAND.first,
        Pay::Currency.all.dig("usd", "unit"),
        Pay::Webhooks.delegator.backend.name,
        Pay::Stripe.model_names.include?("User")
      ]
    end

    assert_equal [nil, "balance_transaction", "$", "ActiveSupport::Notifications", true], result
  end

  test "pay_customer options can be read from a Ractor on Rails main" do
    skip "class_attribute readers are only shareable on Rails main" unless RAILS_MAIN

    result = in_ractor(prepare: -> { User.name && Pay.make_shareable! }) do
      [User.pay_default_payment_processor, User.pay_stripe_customer_attributes, User.pay_braintree_customer_attributes]
    end

    assert_equal [nil, nil, nil], result
  end
end
