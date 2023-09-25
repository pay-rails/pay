require "test_helper"

class Pay::PaddleClassic::Webhooks::SignatureVerifierTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle_classic/subscription_created.json"))
  end

  test "webhook signature is verified correctly" do
    verifier = Pay::PaddleClassic::Webhooks::SignatureVerifier.new(@data)
    assert verifier.verify
  end
end
