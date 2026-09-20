require "test_helper"

class Pay::PaddleBilling::ErrorTest < ActiveSupport::TestCase
  test "re-raised paddle classic exceptions keep the same message" do
    exception = assert_raises {
      begin
        raise ::Paddle::Error, "The connection failed"
      rescue
        raise ::Pay::PaddleBilling::Error
      end
    }

    assert_equal "The connection failed", exception.message
    assert_equal ::Paddle::Error, exception.cause.class
  end

  test "errors raised with a string keep their message" do
    exception = assert_raises(Pay::PaddleBilling::Error) { raise Pay::PaddleBilling::Error, "not supported" }
    assert_equal "not supported", exception.message
  end
end
