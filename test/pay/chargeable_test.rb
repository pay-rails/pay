require "test_helper"

class Pay::Charge::Test < ActiveSupport::TestCase
  setup do
    @charge = Pay.charge_model.new
  end

  test "belongs to a polymorphic owner" do
    @charge.owner = User.new
    assert_equal User, @charge.owner.class
    @charge.owner = Team.new
    assert_equal Team, @charge.owner.class
  end

  test "#charged_to" do
    @charge.card_type = "VISA"
    @charge.card_last4 = 1234
    assert_equal "VISA (**** **** **** 1234)", @charge.charged_to
  end
end
