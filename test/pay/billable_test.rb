require 'test_helper'

class Pay::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.new email: 'gob@bluth.com'
  end

  test 'truth' do
    assert_kind_of Module, Pay::Billable
  end

  test 'has subscriptions' do
    assert @billable.respond_to?(:subscriptions)
  end

  test 'customer with stripe processor' do
    @billable.processor = 'stripe'
    @billable.expects(:stripe_customer).returns(:user)
    assert_equal :user, @billable.customer
  end

  test 'customer with undefined processor' do
    @billable.processor = 'pants'

    assert_raises NoMethodError do
      @billable.customer
    end
  end

  test 'customer without processor' do
    assert_raises StandardError do
      @billable.customer
    end
  end

  test 'subscribing a stripe customer' do
    @billable.processor = 'stripe'
    @billable.expects(:create_stripe_subscription)
             .with('default', 'default', {})
             .returns(:user)

    assert_equal :user, @billable.subscribe
    assert @billable.processor = 'stripe'
  end

  test 'updating a stripe card' do
    @billable.processor = 'stripe'
    @billable.processor_id = 1
    @billable.expects(:update_stripe_card).with('a1b2c3').returns(:card)

    assert_equal :card, @billable.update_card('a1b2c3')
  end

  test 'updating a card without a processor' do
    assert_raises StandardError do
      @billable.update_card('whoops')
    end
  end

  test 'checking for a subscription without one' do
    @billable.stubs(:subscription).returns(nil)
    refute @billable.subscribed?
  end

  test 'checking for a subscription with no plan and active subscription' do
    subscription = mock('subscription')
    subscription.stubs(:active?).returns(true)
    @billable.stubs(:subscription).returns(subscription)

    assert @billable.subscribed?
  end

  test 'checking for a subscription with no plan and inactive subscription' do
    subscription = mock('subscription')
    subscription.stubs(:active?).returns(false)
    @billable.stubs(:subscription).returns(subscription)

    refute @billable.subscribed?
  end

  test 'checking for a subscription that is inactive' do
    subscription = mock('subscription')
    subscription.stubs(:active?).returns(false)
    @billable.stubs(:subscription).returns(subscription)

    refute @billable.subscribed?(name: 'default', processor_plan: 'default')
  end

  test 'checking for a subscription that is active for another plan' do
    subscription = mock('subscription')
    subscription.stubs(:active?).returns(true)
    subscription.stubs(:processor_plan).returns('superior')
    @billable.stubs(:subscription).returns(subscription)

    refute @billable.subscribed?(name: 'default', processor_plan: 'default')
  end

  test 'checking for a subscription that is active for a provided plan' do
    subscription = mock('subscription')
    subscription.stubs(:active?).returns(true)
    subscription.stubs(:processor_plan).returns('default')
    @billable.stubs(:subscription).returns(subscription)

    assert @billable.subscribed?(name: 'default', processor_plan: 'default')
  end

  test 'getting a subscription by default name' do
    subscription = ::Subscription.create!(
      name: 'default',
      owner: @billable,
      processor: 'stripe',
      processor_id: '1',
      processor_plan: 'default',
      quantity: '1'
    )

    assert_equal subscription, @billable.subscription
  end

  test 'getting a stripe subscription' do
    @billable.processor = 'stripe'
    @billable.expects(:stripe_subscription)
             .with('123')
             .returns(:subscription)

    assert_equal :subscription, @billable.processor_subscription('123')
  end

  test 'getting a processor subscription without a processor' do
    assert_raises StandardError do
      @billable.processor_subscription('123')
    end
  end

  test 'pay invoice' do
    @billable.processor = 'stripe'
    @billable.expects(:stripe_invoice!).returns(:invoice)
    assert_equal :invoice, @billable.invoice!
  end

  test 'get upcoming invoice' do
    @billable.processor = 'stripe'
    @billable.expects(:stripe_upcoming_invoice).returns(:invoice)
    assert_equal :invoice, @billable.upcoming_invoice
  end

  test 'has charges' do
    assert @billable.respond_to?(:charges)
  end
end
