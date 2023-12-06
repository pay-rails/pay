module Pay
  module CurrencyHelper
    def pay_amount_to_currency(object, **options)
      Pay::Currency.format(object.amount, **options.merge(currency: object.currency))
    end
  end
end
