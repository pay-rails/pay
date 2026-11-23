require "test_helper"

class Pay::PaddleClassic::DeprecationTest < ActiveSupport::TestCase
  test "warns apps that configured Paddle Classic" do
    assert_deprecated(/Paddle Classic support is deprecated/, Pay.deprecator) do
      Pay::PaddleClassic.warn_deprecated
    end
  end

  test "doesn't warn apps without Paddle Classic credentials" do
    Pay::PaddleClassic.stubs(:vendor_id).returns(nil)
    assert_not_deprecated(Pay.deprecator) do
      Pay::PaddleClassic.warn_deprecated
    end
  end
end
