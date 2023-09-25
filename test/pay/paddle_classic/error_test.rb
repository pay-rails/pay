require "test_helper"

class Pay::PaddleClassic::ErrorTest < ActiveSupport::TestCase
  test "re-raised paddle classic exceptions keep the same message" do
    exception = assert_raises {
      begin
        raise ::PaddlePay::ConnectionError, "The connection failed"
      rescue
        raise ::Pay::PaddleClassic::Error
      end
    }

    assert_equal "The connection failed", exception.message
    assert_equal ::PaddlePay::ConnectionError, exception.cause.class
  end
end
