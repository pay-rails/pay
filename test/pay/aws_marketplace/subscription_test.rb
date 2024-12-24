require "test_helper"

class Pay::AwsMarketplace::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:aws_marketplace)
    @subscription = pay_subscriptions(:aws_marketplace)
  end

  test "aws processor subscription" do
    assert_equal @subscription, @subscription.api_record
  end

  test "aws processor cancel" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.cancel
    end
  end

  test "aws processor trial period" do
    refute @subscription.on_trial?
  end

  test "aws processor cancel_now!" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.cancel_now!
    end
  end

  test "aws processor on_grace_period?" do
    freeze_time do
      @subscription.update(ends_at: 1.week.from_now)
      assert @subscription.on_grace_period?
    end
  end

  test "aws processor resume" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.resume
    end
  end

  test "aws processor swap" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.swap("another_plan")
    end
  end

  test "aws change quantity" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.change_quantity(3)
    end
  end

  test "aws cancel_now! on trial" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @subscription.cancel_now!
    end
  end

  test "aws nonresumable subscription" do
    @subscription.update(ends_at: 1.week.from_now)
    @subscription.reload

    assert @subscription.on_grace_period?
    assert @subscription.canceled?
    refute @subscription.resumable?
  end

  def entitlement
    OpenStruct.new(
      value: OpenStruct.new(integer_value: 5),
      dimension: "team_ep",
      product_code: "et6zix1m4h3qlfta2qy6r7lnw",
      expiration_date: Time.parse("2024-10-26T13:43:42.608+00:00"),
      customer_identifier: "QzOTBiMmRmN"
    )
  end

  test "aws sync with matching customer record" do
    assert_equal @pay_customer, Pay::AwsMarketplace::Customer.find_by(processor_id: entitlement.customer_identifier)

    Pay::AwsMarketplace::Subscription.sync(entitlement)

    subscription = Pay::AwsMarketplace::Subscription.last
    assert_equal 5, subscription.quantity
    assert_equal "team_ep", subscription.name
  end

  test "aws sync with no matching customer record" do
    @pay_customer.destroy
    assert_nil Pay::AwsMarketplace::Customer.find_by(processor_id: entitlement.customer_identifier)

    assert_raises do
      Pay::AwsMarketplace::Subscription.sync(entitlement)
    end
  end

  test "aws sync with no matching customer record but with object" do
    @pay_customer.update!(processor_id: "abc123")
    assert_nil Pay::AwsMarketplace::Customer.find_by(processor_id: entitlement.customer_identifier)

    Pay::AwsMarketplace::Subscription.sync(entitlement, customer: @pay_customer)

    subscription = Pay::AwsMarketplace::Subscription.last
    assert_equal 5, subscription.quantity
    assert_equal "team_ep", subscription.name
  end

  test "aws sync when subscription already exists" do
    @pay_customer.subscriptions.create!(
      status: :active,
      name: "team_ep",
      processor_plan: "et6zix1m4h3qlfta2qy6r7lnw"
    )

    Pay::AwsMarketplace::Subscription.sync(entitlement)

    subscription = Pay::AwsMarketplace::Subscription.last
    assert_equal 5, subscription.quantity
    assert_equal "team_ep", subscription.name
  end
end
