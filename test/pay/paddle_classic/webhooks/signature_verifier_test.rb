require "test_helper"

class Pay::PaddleClassic::Webhooks::SignatureVerifierTest < ActiveSupport::TestCase
  setup do
    @data = json_fixture("paddle_classic/subscription_created")
  end

  test "webhook signature is verified correctly" do
    verifier = Pay::PaddleClassic::Webhooks::SignatureVerifier.new(@data)
    assert verifier.verify
  end
end
