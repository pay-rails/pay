require "test_helper"

class Pay::Charge::Test < ActiveSupport::TestCase
  setup do
    @chargeable = Pay.charge_model.new
  end

  test "#charged_to" do
    @chargeable.card_type = "VISA"
    @chargeable.card_last4 = 1234
    assert_equal "VISA (**** **** **** 1234)", @chargeable.charged_to
  end
end
