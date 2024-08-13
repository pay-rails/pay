require "test_helper"

module Pay
  class BraintreeWebhooksControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test "should handle post requests" do
      post webhooks_braintree_path
      assert_response :bad_request
    end

    test "should parse a braintree webhook" do
      params = json_fixture("braintree/subscription_charged_successfully")

      pay_customer = pay_customers(:braintree)
      pay_customer.update(processor_id: "108696401")
      pay_customer.subscriptions.create!(
        processor_id: "f6rnpm",
        processor_plan: "default",
        name: "default",
        status: "active"
      )

      assert_difference("Pay::Webhook.count") do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_braintree_path, params: params
          assert_response :success
        end
      end

      assert_difference("pay_customer.charges.count") do
        perform_enqueued_jobs
      end
    end
  end
end
