module Pay
  class Charge < ApplicationRecord
    include Pay::Chargeable

    def filename
      "#{created_at.strftime("%Y-%m-%d")}-receipt.pdf"
    end
  end
end
