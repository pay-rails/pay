require "test_helper"

class Pay::Billable::SyncEmail::Test < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "email sync only on updating customer email" do
    billable = User.new(email: "test@example.com", processor_id: "test")

    assert_no_enqueued_jobs do
      billable.save
    end

    assert_enqueued_jobs 1 do
      billable.update(email: "test@test.com")
    end
  end

  test "email sync should be ignored for billable that delegates email" do
    assert_no_enqueued_jobs do
      billable = Team.create(name: "Team 1")
    end
  end
end
