require 'test_helper'

class Pay::Billable::Test < ActiveSupport::TestCase
  def setup
    @billable = Object.new
    @billable.extend(Pay::Billable)
  end

  test 'truth' do
    assert_kind_of Module, Pay::Billable
  end
end
