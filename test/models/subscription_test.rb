require 'test_helper'

class Pay::Subscription::Test < ActiveSupport::TestCase
  setup do
    @subscription = Subscription.new
  end

  test 'belongs to the owner' do
    klass = Subscription.reflections["owner"].options[:class_name]
    assert klass, "User"
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
end
