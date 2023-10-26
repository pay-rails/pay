require "test_helper"

module Pay
  class PaddleBillingControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test "should handle post requests" do
      post webhooks_paddle_billing_path
      assert_response :bad_request
    end

    test "should parse a paddle billing webhook" do
      user = pay_customers(:paddle_billing)

      Pay::Webhooks::PaddleBillingController.any_instance.expects(:valid_signature?).returns(true)

      assert_difference("Pay::Webhook.count") do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_paddle_billing_path, params: fake_event("paddle_billing/subscription.created")
          assert_response :success
        end
      end

      assert_difference("user.subscriptions.count") do
        perform_enqueued_jobs
      end
    end
  end
end
