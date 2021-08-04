require "test_helper"

module Pay
  class CustomerSyncJobTest < ActiveJob::TestCase
    test "user with stripe as processor" do
      Pay::Stripe::Billable.any_instance.expects(:update_customer!)
      Pay::CustomerSyncJob.perform_now(pay_customers(:stripe).id)
    end

    test "user with braintree as processor" do
      Pay::Braintree::Billable.any_instance.expects(:update_customer!)
      Pay::CustomerSyncJob.perform_now(pay_customers(:braintree).id)
    end
  end
end
