require 'test_helper'

class Pay::Subscription::Test < ActiveSupport::TestCase
  setup do
    @subscription = ::Subscription.new processor: 'stripe'
  end

  test 'belongs to the owner' do
    klass = ::Subscription.reflections['owner'].options[:class_name]
    assert klass, 'User'
  end

  test '.for_name(name) scope' do
    owner = User.create

    subscription1 = ::Subscription.create!(
      name: 'default',
      owner: owner,
      processor: 'stripe',
      processor_id: '1',
      processor_plan: 'default',
      quantity: '1'
    )

    subscription2 = ::Subscription.create!(
      name: 'superior',
      owner: owner,
      processor: 'stripe',
      processor_id: '1',
      processor_plan: 'superior',
      quantity: '1'
    )

    assert_includes ::Subscription.for_name('default'), subscription1
    refute_includes ::Subscription.for_name('default'), subscription2
  end

  test 'active trial' do
    @subscription.trial_ends_at = 5.minutes.from_now
    assert @subscription.on_trial?
  end

  test 'inactive trial' do
    @subscription.trial_ends_at = 5.minutes.ago
    refute @subscription.on_trial?
  end

  test 'no trial' do
    @subscription.trial_ends_at = nil
    refute @subscription.on_trial?
  end

  test 'cancelled' do
    @subscription.ends_at = 1.week.ago
    assert @subscription.cancelled?
  end

  test 'not cancelled' do
    @subscription.ends_at = nil
    refute @subscription.cancelled?
  end

  test 'on grace period' do
    @subscription.ends_at = 5.minutes.from_now
    assert @subscription.on_grace_period?
  end

  test 'off grace period' do
    @subscription.ends_at = 5.minutes.ago
    refute @subscription.on_grace_period?
  end

  test 'no grace period' do
    @subscription.ends_at = nil
    refute @subscription.on_grace_period?
  end

  test 'active' do
    @subscription.ends_at = nil
    @subscription.trial_ends_at = nil
    assert @subscription.active?
  end

  test 'inactive' do
    @subscription.ends_at = 5.minutes.ago
    @subscription.trial_ends_at = nil
    refute @subscription.active?
  end

  test 'cancel' do
    expiration = 2.weeks.from_now

    stripe_sub = mock('stripe_subscription')
    stripe_sub.expects(:cancel_at_period_end=).with(true)
    stripe_sub.expects(:save)
    stripe_sub.expects(:current_period_end).returns(expiration)

    @subscription.stubs(:processor_subscription).returns(stripe_sub)
    @subscription.cancel

    assert @subscription.ends_at, expiration
  end

  test 'cancel_now!' do
    cancelled_stripe = mock('cancelled_stripe_subscription')

    stripe_sub = mock('stripe_subscription')
    stripe_sub.expects(:delete).returns(cancelled_stripe)

    @subscription.stubs(:processor_subscription).returns(stripe_sub)
    @subscription.cancel_now!

    assert @subscription.ends_at <= Time.zone.now
  end

  test 'resume on grace period' do
    @subscription.ends_at = 2.weeks.from_now

    stripe_sub = mock('stripe_subscription')
    stripe_sub.expects(:plan=)
    stripe_sub.expects(:trial_end=)
    stripe_sub.expects(:cancel_at_period_end=)
    stripe_sub.expects(:save).returns(true)

    @subscription.processor_plan = 'default'

    @subscription.stubs(:on_grace_period?).returns(true)
    @subscription.stubs(:processor_subscription).returns(stripe_sub)
    @subscription.stubs(:on_trial?).returns(false)

    @subscription.resume

    assert_nil @subscription.ends_at
  end

  test 'resume off grace period' do
    @subscription.stubs(:on_grace_period?).returns(false)

    assert_raises StandardError do
      @subscription.resume
    end
  end

  test 'processor subscription' do
    user = mock('user')
    user.expects(:processor_subscription).returns(:result)

    @subscription.stubs(:owner).returns(user)

    assert_equal :result, @subscription.processor_subscription
  end

  test 'can swap plans' do
    stripe_sub = mock('stripe_subscription')
    stripe_sub.expects(:plan=).returns("yearly")
    stripe_sub.expects(:prorate=)
    stripe_sub.expects(:trial_end=)
    stripe_sub.expects(:quantity=)
    stripe_sub.expects(:save)
    stripe_sub.expects(:plan).returns("yearly")

    @subscription.stubs(:processor_subscription).returns(stripe_sub)
    @subscription.swap("yearly")

    assert_equal "yearly", @subscription.processor_subscription.plan
  end
end
