require "test_helper"

class Pay::Webhooks::LemonSqueezyControllerTest < EngineIntegrationTest
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

  test "responds bad request to a bad signature" do
    post webhooks_lemon_squeezy_path, params: json_fixture("lemon_squeezy/subscription_created"), headers: {"X-Signature" => "garbage"}
    assert_response :bad_request
  end

  test "accepts a request signed with the signing secret" do
    Pay::LemonSqueezy.stubs(:signing_secret).returns("lemon_secret")
    body = {meta: {event_name: "subscription_created"}}.to_json

    post webhooks_lemon_squeezy_path, params: body, headers: {"Content-Type" => "application/json", "X-Signature" => OpenSSL::HMAC.hexdigest("sha256", "lemon_secret", body)}
    assert_response :success
  end

  test "rejects a request signed with an empty key when no signing secret is configured" do
    Pay::LemonSqueezy.stubs(:signing_secret).returns(nil)
    body = {meta: {event_name: "subscription_created"}}.to_json

    assert_no_difference("Pay::Webhook.count") do
      post webhooks_lemon_squeezy_path, params: body, headers: {"Content-Type" => "application/json", "X-Signature" => OpenSSL::HMAC.hexdigest("sha256", "", body)}
    end
    assert_response :bad_request
  end

  test "rejects a request signed with an empty key when the signing secret is blank" do
    Pay::LemonSqueezy.stubs(:signing_secret).returns("")
    body = {meta: {event_name: "subscription_created"}}.to_json

    post webhooks_lemon_squeezy_path, params: body, headers: {"Content-Type" => "application/json", "X-Signature" => OpenSSL::HMAC.hexdigest("sha256", "", body)}
    assert_response :bad_request
  end
end
