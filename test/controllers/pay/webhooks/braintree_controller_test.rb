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
      user = User.create!
      user.set_payment_processor :braintree
      user.payment_processor.subscriptions.create!(
        processor_id: "f6rnpm",
        processor_plan: "default",
        name: "default",
        status: "active"
      )

      params = fake_event "braintree/subscription_charged_successfully"

      assert_difference("user.charges.count") do
        post webhooks_braintree_path, params: params
        assert_response :success
      end
    end
  end
end
