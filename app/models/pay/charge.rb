module Pay
  class Charge < ApplicationRecord
    include Pay::Chargeable

    scope :sorted, ->{ order(created_at: :desc) }
    default_scope ->{ sorted }

    def filename
      "receipt-#{created_at.strftime("%Y-%m-%d")}.pdf"
    end
  end
end
