module Pay
  class Charge < ApplicationRecord
    include Pay::Chargeable
  end
end
