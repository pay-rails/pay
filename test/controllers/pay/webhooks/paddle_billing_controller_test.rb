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
      Pay::Webhooks::PaddleBillingController.any_instance.expects(:valid_signature?).returns(true)

      assert_difference("Pay::Webhook.count") do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_paddle_billing_path, params: json_fixture("paddle_billing/subscription.created")
          assert_response :success
        end
      end

      assert_difference -> { pay_customers(:paddle_billing).subscriptions.count } do
        perform_enqueued_jobs
      end
    end

    test "uses constant-time comparison for paddle billing signatures" do
      controller = Pay::Webhooks::PaddleBillingController.new
      timestamp = "1730000000"
      body = {event_type: "transaction.completed"}.to_json
      secret = "paddle-signing-secret"
      hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("sha256"), secret, "#{timestamp}:#{body}")

      controller.stubs(:request).returns(stub(raw_post: body))
      Pay::PaddleBilling.stubs(:signing_secret).returns(secret)
      ActiveSupport::SecurityUtils.expects(:secure_compare).with(hmac, hmac).returns(true)

      assert controller.send(:valid_signature?, "ts=#{timestamp};h1=#{hmac}")
    end
  end
end
