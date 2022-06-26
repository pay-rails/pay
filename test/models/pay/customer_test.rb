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

  test "update_customer!" do
    assert pay_customers(:fake).respond_to?(:update_customer!)
  end

  test "subscription should be consistent regardless of loaded subscriptions or not" do
    # This test assures a consistent pay_customer#subscription regardless of
    # pay_customer#subscriptions being previously loaded or not.

    # Before the introduction of the scope `-> { order({ id: :asc }) }` in
    # Customer.has_many(:subscriptions), calling customer#subscription was
    # non-deterministic if the subscriptions were already loaded.

    # That happened because in Postgres, if an order clause is not specified,
    # the results return in non-deterministic order
    # (https://stackoverflow.com/questions/6585574/postgres-default-sort-by-id-worldship).

    # Psql will give the impression of returning records in ascending primary
    # key (ID) order, but it turns out if you update a previously created
    # record, it will start appearing first. This is what this test simulates
    # by updating subscription_1.

    # If that association scope is removed, this test fails in psql only
    # (see bin/test_databases for multi-db tests).

    @pay_customer = pay_customers(:stripe)

    subscription_1 = create_subscription

    assert_equal @pay_customer.subscription, subscription_1

    subscription_2 = create_subscription(status: "canceled")

    assert_equal @pay_customer.subscription, subscription_2

    assert_equal @pay_customer.subscription, subscription_2

    subscription_1.update_columns(status: "canceled")

    @pay_customer.reload

    assert_not @pay_customer.subscriptions.loaded?

    @pay_customer.subscriptions.load

    assert_equal @pay_customer.subscription, subscription_2
  end
end
