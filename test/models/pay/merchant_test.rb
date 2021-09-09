require "test_helper"

class Pay::MerchantTest < ActiveSupport::TestCase
  test "text data column" do
    pay_merchants(:one).update!(onboarding_complete: true)
    assert_equal true, pay_merchants(:one).onboarding_complete
  end
end
