module Pay
  class Merchant < Pay::ApplicationRecord
    belongs_to :owner, polymorphic: true

    validates :processor, presence: true

    store_accessor :data, :onboarding_complete

    delegate_missing_to :pay_processor

    def self.processor_for(name)
      "Pay::#{name.to_s.classify}::Merchant".constantize
    end

    def pay_processor
      @pay_processor ||= self.class.processor_for(processor).new(self)
    end
  end
end
