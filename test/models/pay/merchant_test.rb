require "test_helper"

class Pay::MerchantTest < ActiveSupport::TestCase
  test "should return stripe connect onboarding status" do
    merchant = Pay::Merchant.new
    assert_equal false, merchant.onboarding_complete?

    merchant.onboarding_complete = true
    assert_equal true, merchant.onboarding_complete?
  end
end
