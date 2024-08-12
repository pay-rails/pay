require "test_helper"

class Pay::AttributesTest < ActiveSupport::TestCase
  test "set payment processor" do
    user = users(:none)
    refute user.payment_processor

    assert_difference "Pay::Customer.count" do
      assert_indexed_selects do
        user.set_payment_processor :stripe
      end
    end

    assert user.payment_processor
  end

  test "set payment processor types" do
    user = users(:none)
    refute user.payment_processor

    assert_equal Pay::FakeProcessor::Customer, user.set_payment_processor(:fake_processor, allow_fake: true).class
    assert_equal Pay::LemonSqueezy::Customer, user.set_payment_processor(:lemon_squeezy).class
    assert_equal Pay::PaddleBilling::Customer, user.set_payment_processor(:paddle_billing).class
    assert_equal Pay::PaddleClassic::Customer, user.set_payment_processor(:paddle_classic).class
    assert_equal Pay::Stripe::Customer, user.set_payment_processor(:stripe).class
  end

  test "set payment processor with previously deleted processor" do
    user = users(:deleted_customer)
    assert user.pay_customers.last.deleted_at?
    refute user.payment_processor

    assert_difference "Pay::Customer.where(processor: :stripe).count" do
      user.set_payment_processor :stripe
    end

    assert user.payment_processor
  end

  test "deleting user doesn't remove pay customers" do
    user = users(:stripe)
    ::Stripe::Subscription.stub(:cancel, user.payment_processor.subscription) do
      assert_no_difference "Pay::Customer.count" do
        user.destroy
      end
    end
  end

  test "deleting user cancels subscriptions" do
    user = users(:stripe)
    ::Stripe::Subscription.stub(:cancel, user.payment_processor.subscription) do
      assert user.payment_processor.subscription.active?
      user.destroy
      refute user.payment_processor.subscription.active?
    end
  end

  test "deleting user ignores canceled subscriptions" do
    user = users(:stripe)
    ::Stripe::Subscription.stub(:cancel, user.payment_processor.subscription) do
      user.payment_processor.subscription.cancel_now!
      refute user.payment_processor.subscription.active?
      user.destroy
    end
  end

  test "set merchant processor" do
    account = accounts(:one)
    refute account.merchant_processor

    assert_difference "Pay::Merchant.count" do
      assert_indexed_selects do
        account.set_merchant_processor :stripe
      end
    end

    assert account.merchant_processor
  end

  test "pay_customer stripe attributes" do
    original_value = User.pay_stripe_customer_attributes
    User.pay_stripe_customer_attributes = :stripe_attributes
    assert_equal :stripe_attributes, User.pay_stripe_customer_attributes
    User.pay_stripe_customer_attributes = original_value
  end

  test "pay_customer braintree attributes" do
    original_value = User.pay_braintree_customer_attributes
    User.pay_braintree_customer_attributes = :braintree_attributes
    assert_equal :braintree_attributes, User.pay_braintree_customer_attributes
    User.pay_braintree_customer_attributes = original_value
  end

  test "default_payment_processor option" do
    original_value = User.pay_default_payment_processor
    User.pay_default_payment_processor = :fake_processor
    payment_processor = users(:none).payment_processor
    assert payment_processor
    assert_equal "fake_processor", payment_processor.processor
    User.pay_default_payment_processor = original_value
  end

  test "add payment processor without making it default" do
    user = users(:stripe)
    assert_equal "stripe", user.payment_processor.processor

    result = user.add_payment_processor :fake_processor, allow_fake: true
    assert_not_equal "stripe", result.processor
    assert_equal "stripe", user.payment_processor.processor
  end
end
