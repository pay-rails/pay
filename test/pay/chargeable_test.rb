require 'test_helper'

class Pay::Chargeable::Test < ActiveSupport::TestCase
  setup do
    @chargeable = Charge.new
  end

  test 'truth' do
    assert_kind_of Module, Pay::Chargeable
  end

  test '#charged_to' do
    @chargeable.card_type = 'VISA'
    @chargeable.card_last4 = 1234
    assert_equal "VISA (**** **** **** 1234)", @chargeable.charged_to
  end

  test '#receipt is only available if Receipts::Receipt is defined' do
    refute @chargeable.respond_to?(:receipt)

    module Receipts
      def receipt; end
    end

    class MyCharge < Charge
      include Pay::Chargeable
      include Receipts
    end

    mychargeable = MyCharge.new
    assert mychargeable.respond_to?(:receipt)
  end
end
