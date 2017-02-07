require 'test_helper'

class Pay::Billable::Test < ActiveSupport::TestCase
  def setup
    @billable = User.new
    @billable.extend(Pay::Billable)
  end

  test 'truth' do
    assert_kind_of Module, Pay::Billable
  end

  test 'has subscriptions' do
    assert @billable.respond_to?(:subscriptions)
  end
end
