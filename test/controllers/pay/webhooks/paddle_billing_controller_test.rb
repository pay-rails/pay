require "test_helper"

class Pay::Webhooks::PaddleBillingControllerTest < EngineIntegrationTest
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

  # One request per test: on Rails 7.0 the engine routes don't survive a second request in the same test
  test "responds bad request to a signature header without parts" do
    post webhooks_paddle_billing_path, params: json_fixture("paddle_billing/subscription.created"), headers: {"Paddle-Signature" => "garbage"}
    assert_response :bad_request
  end

  test "responds bad request to a signature header with an empty hash" do
    post webhooks_paddle_billing_path, params: json_fixture("paddle_billing/subscription.created"), headers: {"Paddle-Signature" => "ts=1;h1="}
    assert_response :bad_request
  end

  test "accepts a request signed with the signing secret" do
    Pay::PaddleBilling.stubs(:signing_secret).returns("paddle_secret")
    body = {event_type: "subscription.created"}.to_json
    h1 = OpenSSL::HMAC.hexdigest("sha256", "paddle_secret", "1:#{body}")

    post webhooks_paddle_billing_path, params: body, headers: {"Content-Type" => "application/json", "Paddle-Signature" => "ts=1;h1=#{h1}"}
    assert_response :success
  end

  test "rejects a request signed with an empty key when no signing secret is configured" do
    Pay::PaddleBilling.stubs(:signing_secret).returns(nil)
    body = {event_type: "subscription.created"}.to_json
    h1 = OpenSSL::HMAC.hexdigest("sha256", "", "1:#{body}")

    assert_no_difference("Pay::Webhook.count") do
      post webhooks_paddle_billing_path, params: body, headers: {"Content-Type" => "application/json", "Paddle-Signature" => "ts=1;h1=#{h1}"}
    end
    assert_response :bad_request
  end

  test "rejects a request signed with an empty key when the signing secret is blank" do
    Pay::PaddleBilling.stubs(:signing_secret).returns("")
    body = {event_type: "subscription.created"}.to_json
    h1 = OpenSSL::HMAC.hexdigest("sha256", "", "1:#{body}")

    post webhooks_paddle_billing_path, params: body, headers: {"Content-Type" => "application/json", "Paddle-Signature" => "ts=1;h1=#{h1}"}
    assert_response :bad_request
  end
end
