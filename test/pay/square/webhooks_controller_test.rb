require "test_helper"

class Pay::Square::WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    VCR.eject_cassette while VCR.current_cassette
    WebMock.reset!
    WebMock.disable_net_connect!
  end

  teardown do
    WebMock.allow_net_connect!
  end

  def body
    {
      merchant_id: "MERCHANT_1",
      type: "payment.created",
      event_id: "evt_test_1",
      data: {type: "payment", id: "pmt_test", object: {payment: {id: "pmt_test", customer_id: "sqcust_test"}}}
    }.to_json
  end

  def signature_for(raw, url: Pay::Square.webhook_notification_url, key: Pay::Square.signing_secret)
    Base64.strict_encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), key, url + raw))
  end

  test "accepts a correctly signed webhook and enqueues processing" do
    raw = body
    assert_difference -> { Pay::Webhook.count }, +1 do
      post "/pay/webhooks/square", params: raw, headers: {
        "CONTENT_TYPE" => "application/json",
        "x-square-hmacsha256-signature" => signature_for(raw)
      }
    end
    assert_response :ok
  end

  test "rejects a webhook with an invalid signature" do
    raw = body
    assert_no_difference -> { Pay::Webhook.count } do
      post "/pay/webhooks/square", params: raw, headers: {
        "CONTENT_TYPE" => "application/json",
        "x-square-hmacsha256-signature" => "obviously-wrong-signature"
      }
    end
    assert_response :bad_request
  end

  test "rejects a webhook whose body was tampered after signing" do
    signed = body
    signature = signature_for(signed)
    tampered = body.sub("pmt_test", "pmt_attacker")

    assert_no_difference -> { Pay::Webhook.count } do
      post "/pay/webhooks/square", params: tampered, headers: {
        "CONTENT_TYPE" => "application/json",
        "x-square-hmacsha256-signature" => signature
      }
    end
    assert_response :bad_request
  end
end
