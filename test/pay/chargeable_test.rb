require 'test_helper'

class Pay::Chargeable::Test < ActiveSupport::TestCase
  setup do
    user = User.new email: 'gob@bluth.com'
    @chargeable = Charge.new(card_type: 'VISA', card_last4: 1234)
  end

  test 'truth' do
    assert_kind_of Module, Pay::Chargeable
  end

  test '#charged_to' do
    assert_equal "VISA (**** **** **** 1234)", @chargeable.charged_to
  end
end
