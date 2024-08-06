require "test_helper"

class Pay::LemonSqueezy::ErrorTest < ActiveSupport::TestCase
  test "re-raised lemon squeezy exceptions keep the same message" do
    exception = assert_raises {
      begin
        raise ::LemonSqueezy::Error, "The connection failed"
      rescue
        raise ::Pay::LemonSqueezy::Error
      end
    }

    assert_equal "The connection failed", exception.message
    assert_equal ::LemonSqueezy::Error, exception.cause.class
  end
end
