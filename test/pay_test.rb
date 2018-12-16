require 'test_helper'

class Pay::Test < ActiveSupport::TestCase
  test 'truth' do
    assert_kind_of Module, Pay
  end

  test 'default billable class is user' do
    assert Pay.billable_class, 'User'
  end

  test 'default billable table is users' do
    assert Pay.billable_table, 'users'
  end

  test 'default chargeable class is Charge' do
    assert Pay.chargeable_class, 'Charge'
  end

  test 'default chargeable table is charges' do
    assert Pay.chargeable_table, 'charges'
  end
end
