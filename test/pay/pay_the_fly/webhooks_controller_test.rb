# frozen_string_literal: true

require "test_helper"

class Pay::Webhooks::PayTheFlyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project_key = "test_project_key_abc123"
  end

  test "valid payment webhook returns success" do
    data = {
      project_id: "proj1",
      chain_symbol: "BSC",
      tx_hash: "0x" + "a" * 64,
      wallet: "0x" + "b" * 40,
      value: "10000000000000000",
      fee: "100000000000000",
      serial_no: "ORDER001",
      tx_type: 1,
      confirmed: true,
      create_at: Time.current.to_i
    }.to_json

    timestamp = Time.current.to_i
    sign = OpenSSL::HMAC.hexdigest("SHA256", @project_key, "#{data}.#{timestamp}")

    payload = {data: data, sign: sign, timestamp: timestamp}.to_json

    Pay::PayTheFly.stub(:project_key, @project_key) do
      post "/pay/webhooks/pay_the_fly",
        params: payload,
        headers: {"CONTENT_TYPE" => "application/json"}

      assert_response :success
      body = JSON.parse(response.body)
      assert_includes body["status"], "success"
    end
  end

  test "invalid signature returns bad_request" do
    data = {tx_type: 1, confirmed: true}.to_json
    payload = {data: data, sign: "invalid", timestamp: Time.current.to_i}.to_json

    Pay::PayTheFly.stub(:project_key, @project_key) do
      post "/pay/webhooks/pay_the_fly",
        params: payload,
        headers: {"CONTENT_TYPE" => "application/json"}

      assert_response :bad_request
    end
  end

  test "malformed JSON returns bad_request" do
    Pay::PayTheFly.stub(:project_key, @project_key) do
      post "/pay/webhooks/pay_the_fly",
        params: "not json at all",
        headers: {"CONTENT_TYPE" => "application/json"}

      assert_response :bad_request
    end
  end

  test "missing signature fields returns bad_request" do
    payload = {data: "{}", timestamp: Time.current.to_i}.to_json
    # sign is missing

    Pay::PayTheFly.stub(:project_key, @project_key) do
      post "/pay/webhooks/pay_the_fly",
        params: payload,
        headers: {"CONTENT_TYPE" => "application/json"}

      assert_response :bad_request
    end
  end
end
