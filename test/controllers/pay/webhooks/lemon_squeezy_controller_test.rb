require "test_helper"

module Pay
  class LemonSqueezyControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test "should handle post requests" do
      post webhooks_lemon_squeezy_path
      assert_response :bad_request
    end

    test "should parse a lemon squeezy webhook" do
      Pay::Webhooks::LemonSqueezyController.any_instance.expects(:valid_signature?).returns(true)

      assert_difference("Pay::Webhook.count") do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_lemon_squeezy_path, params: json_fixture("lemon_squeezy/subscription_created")
          assert_response :success
        end
      end
    end
  end
end
