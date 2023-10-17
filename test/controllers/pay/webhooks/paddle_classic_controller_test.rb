require "test_helper"

module Pay
  class PaddleClassicControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test "should handle post requests" do
      post webhooks_paddle_classic_path
      assert_response :bad_request
    end

    test "should parse a paddle classic webhook" do
      user = User.create!
      params = fake_event "paddle_classic/subscription_created"

      GlobalID::Locator.expects(:locate_signed).returns(user)

      assert_difference("Pay::Webhook.count") do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_paddle_classic_path, params: params
          assert_response :success
        end
      end

      assert_difference("user.subscriptions.count") do
        perform_enqueued_jobs
      end
    end
  end
end
