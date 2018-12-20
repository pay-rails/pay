class Charge < ApplicationRecord
  include Pay::Chargeable

  validates :processor_id, uniqueness: { scope: :processor }
end
