require "test_helper"

class Pay::Billable::SyncCustomerTest < ActiveSupport::TestCase
  test "customer sync only on updating customer email" do
    assert_no_enqueued_jobs do
      User.create(email: "test@example.com")
    end

    assert_enqueued_with(job: Pay::CustomerSyncJob, args: [users(:stripe).payment_processor.id]) do
      users(:stripe).update(email: "test@test.com")
    end
  end

  test "customer sync on updating with pay_should_sync_customer? overriden" do
    assert_no_enqueued_jobs do
      User.create(email: "test@example.com")
    end

    assert_enqueued_with(job: Pay::CustomerSyncJob, args: [users(:stripe).payment_processor.id]) do
      user = users(:stripe)
      def user.pay_should_sync_customer?
        true
      end

      users(:stripe).update(first_name: "whatever")
    end
  end

  test "email sync should be ignored for billable that delegates email" do
    assert_no_enqueued_jobs do
      Team.create(name: "Team 1")
    end
  end

  test "queues multiple jobs if a user has multiple payment processors" do
    user = users(:multiple)
    assert_enqueued_jobs 2 do
      user.update(email: "test@test.com")
    end
  end

  test "does not sync deleted customers" do
    user = users(:deleted_customer)
    assert_no_enqueued_jobs only: Pay::CustomerSyncJob do
      assert user.update(email: "deleted-updated@example.org")
    end
    assert user.saved_change_to_email?
  end

  test "only syncs active customers when some are deleted" do
    user = users(:multiple)
    pay_customers(:multiple_second).update!(deleted_at: Time.current)

    assert_enqueued_jobs 1, only: Pay::CustomerSyncJob do
      assert_enqueued_with(job: Pay::CustomerSyncJob, args: [pay_customers(:multiple_first).id]) do
        user.update(email: "test@test.com")
      end
    end
  end
end
