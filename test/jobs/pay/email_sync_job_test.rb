require "test_helper"

module Pay
  class EmailSyncJobTest < ActiveJob::TestCase
    setup do
      @billable = User.new email: "johnny@appleseed.com"
    end

    test "user with stripe as processor" do
      @billable.processor = "stripe"
      User.stubs(:find).returns(@billable)
      Pay::Stripe::Billable.any_instance.expects(:update_email!)
      Pay::EmailSyncJob.perform_now(@billable.id, @billable.class.name)
    end

    test "user with braintree as processor" do
      @billable.processor = "braintree"
      User.stubs(:find).returns(@billable)
      Pay::Braintree::Billable.any_instance.expects(:update_email!)
      Pay::EmailSyncJob.perform_now(@billable.id, @billable.class.name)
    end
  end
end
