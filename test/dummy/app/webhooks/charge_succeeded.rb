class ChargeSucceeded
  def call(event)
    Rails.logger.debug event
  end
end
