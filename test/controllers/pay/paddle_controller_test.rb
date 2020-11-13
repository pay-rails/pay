require "test_helper"

module Pay
  class PaddleControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test "should handle post requests" do
      post webhooks_paddle_path
      assert_response :success
    end

    test "should parse a paddle webhook" do
      user = User.create!
      params = JSON.parse(File.read("test/support/fixtures/paddle/subscription_created.json"))

      assert_difference("Pay.subscription_model.count") do
        post webhooks_paddle_path, params: params
        assert_response :success
      end
    end
  end
end