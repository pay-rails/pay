require "test_helper"

class Pay::CustomerTest < ActiveSupport::TestCase
  test "active customers" do
    results = Pay::Customer.active
    assert_includes results, pay_customers(:stripe)
    refute_includes results, pay_customers(:deleted)
  end

  test "deleted customers" do
    assert_includes Pay::Customer.deleted, pay_customers(:deleted)
  end

  test "active?" do
    assert pay_customers(:stripe).active?
  end

  test "deleted?" do
    assert pay_customers(:deleted).deleted?
  end

  test "update_api_record" do
    assert pay_customers(:fake).respond_to?(:update_api_record)
  end

  test "update_api_record with a promotion code" do
    pay_customer = pay_customers(:fake)
    assert pay_customer.update_api_record(promotion_code: "promo_xxx123")
  end

  test "subscription prefers an active subscription over a newer canceled one" do
    pay_customer = pay_customers(:fake)
    active = pay_customer.subscriptions.first
    canceled = pay_customer.subscriptions.create!(processor_id: "fake_2", name: "default", processor_plan: "default", status: "canceled", ends_at: 1.day.ago, created_at: 1.day.from_now)

    assert_equal active, pay_customer.subscription
    assert_not_equal canceled, pay_customer.subscription
  end

  test "subscription prefers a paused subscription over a newer canceled one" do
    pay_customer = pay_customers(:fake)
    paused = pay_customer.subscriptions.first
    paused.update!(status: "paused")
    pay_customer.subscriptions.create!(processor_id: "fake_2", name: "default", processor_plan: "default", status: "canceled", ends_at: 1.day.ago, created_at: 1.day.from_now)

    assert_equal paused, pay_customer.subscription
  end

  test "subscription falls back to the most recent subscription when none are active" do
    pay_customer = pay_customers(:fake)
    pay_customer.subscriptions.first.update!(status: "canceled", ends_at: 2.days.ago)
    newer = pay_customer.subscriptions.create!(processor_id: "fake_2", name: "default", processor_plan: "default", status: "canceled", ends_at: 1.day.ago, created_at: 1.day.from_now)

    assert_equal newer, pay_customer.subscription
  end

  test "subscription returns nil when there are no subscriptions for the name" do
    assert_nil pay_customers(:fake).subscription(name: "nonexistent")
  end

  test "not_fake scope" do
    assert_not_includes Pay::Customer.not_fake_processor, pay_customers(:fake)
    assert_includes Pay::Customer.not_fake_processor, pay_customers(:stripe)
  end
end
