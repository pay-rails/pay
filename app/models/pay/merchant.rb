module Pay
  class Merchant < Pay::ApplicationRecord
    belongs_to :owner, polymorphic: true

    validates :processor, presence: true

    store_accessor :data, :onboarding_complete

    def onboarding_complete?
      ActiveModel::Type::Boolean.new.cast(data&.fetch("onboarding_complete")) || false
    end
  end
end
