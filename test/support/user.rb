class User < ActiveRecord::Base
  include Pay::Billable
end
