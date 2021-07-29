class Pay::Merchant < Pay::ApplicationRecord
  belongs_to :owner, polymorphic: true

  store_accessor :pay_data, :onboarding_complete

  validates :processor, presence: true
  validate :only_one_default

  delegate_missing_to :pay_merchant

  def self.processor_for(name)
    "Pay::#{name.to_s.classify}::Merchant".constantize
  end

  def pay_merchant
    @pay_merchant ||= self.class.processor_for(processor).new(self)
  end

  def onboarding_complete?
    !!onboarding_complete
  end

  private

  def only_one_default
    if default? && owner.pay_merchants.where(default: true).where.not(id: id).exists?
      errors.add :base, "Cannot have multiple default merchant accounts"
    end
  end
end
