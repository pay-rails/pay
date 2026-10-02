require "test_helper"

class Pay::LemonSqueezy::WebhooksTest < ActiveSupport::TestCase
  test "lemon squeezy webhook metadata" do
    fixture = json_fixture("lemon_squeezy/order_created")
    object = Pay::LemonSqueezy.construct_from_webhook_event fixture
    assert_equal ::LemonSqueezy::Order, object.class
    assert_equal fixture["meta"], object.meta
  end
end
