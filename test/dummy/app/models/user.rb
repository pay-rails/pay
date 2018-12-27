class User < ApplicationRecord
  include Pay::Billable
end
