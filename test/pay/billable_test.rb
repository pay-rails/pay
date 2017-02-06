require 'test_helper'
require 'activemodel/associations'

class User
  include ActiveModel::Model
  include ActiveModel::Associations

  # need hash like accessor, used internal Rails
  def [](attr)
    self.send(attr)
  end

  # need hash like accessor, used internal Rails
  def []=(attr, value)
    self.send("#{attr}=", value)
  end

  include Pay::Billable
end

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
