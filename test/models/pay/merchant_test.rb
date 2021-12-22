require "test_helper"

class Pay::MerchantTest < ActiveSupport::TestCase
  test "should return stripe connect onboarding status" do
    merchant = Pay::Merchant.new
    refute merchant.onboarding_complete?

    merchant.onboarding_complete = true
    assert merchant.onboarding_complete?
  end
end
