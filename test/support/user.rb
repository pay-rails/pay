class User < ActiveRecord::Base
  include Pay::Billable
  attr_reader :email
end
