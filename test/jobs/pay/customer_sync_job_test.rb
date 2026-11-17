require "test_helper"

module Pay
  class CustomerSyncJobTest < ActiveJob::TestCase
    test "sync customer with stripe" do
      ::Stripe::Customer.expects(:update)
      Pay::CustomerSyncJob.perform_now(pay_customers(:stripe).id)
    end

    test "sync customer with braintree" do
      ::Braintree::CustomerGateway.any_instance.expects(:update)
      Pay::CustomerSyncJob.perform_now(pay_customers(:braintree).id)
    end

    test "skips customers deleted after the job was enqueued" do
      ::Stripe::Customer.expects(:update).never
      Pay::CustomerSyncJob.perform_now(pay_customers(:deleted).id)
    end

    test "skips missing customers" do
      assert_nothing_raised { Pay::CustomerSyncJob.perform_now(0) }
    end
  end
end
