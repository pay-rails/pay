module Pay
  class Merchant < Pay::ApplicationRecord
    belongs_to :owner, polymorphic: true

    validates :processor, presence: true

    store_accessor :data, :onboarding_complete

    delegate_missing_to :pay_processor

    def self.pay_processor_for(name)
      "Pay::#{name.to_s.classify}::Merchant".constantize
    end

    def pay_processor
      return if processor.blank?
      @pay_processor ||= self.class.pay_processor_for(processor).new(self)
    end

    def onboarding_complete?
      ActiveModel::Type::Boolean.new.cast(
        (data.presence || {})["onboarding_complete"]
      )
    end
  end
end
