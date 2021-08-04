class Pay::PaymentMethod < Pay::ApplicationRecord
  belongs_to :customer
end
