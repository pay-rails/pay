# frozen_string_literal: true

require "test_helper"

class WebhookRoutesTest < ActionDispatch::IntegrationTest
  test "stripe webhook routes get mounted correctly" do
    post "/pay/webhooks/stripe", as: :json
    assert_response :bad_request
  end

  test "braintree webhook routes get mounted correctly" do
    post "/pay/webhooks/braintree", as: :json
    assert_response :bad_request
  end

  test "paddle classic webhook routes get mounted correctly" do
    post "/pay/webhooks/paddle_classic", as: :json
    assert_response :bad_request
  end
end
