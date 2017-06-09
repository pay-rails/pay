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

  test 'default billable key is user_id' do
    assert Pay.billable_table, 'user_id'
  end
end
