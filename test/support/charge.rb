class Charge < ActiveRecord::Base
  include Pay::Chargeable
end