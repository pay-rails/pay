module Pay
  module Square
    class PaymentMethod < Pay::PaymentMethod
      # Pass `object` (the Square card) when you have it; otherwise it is re-fetched.
      def self.sync(card_id, object: nil, pay_customer: nil, try: 0, retries: 1)
        object ||= Pay::Square.with_client(pay_customer) { |client| client.cards.get(card_id: card_id) }.card
        return if object.nil?

        pay_customer ||= Pay::Customer.find_by(processor: :square, processor_id: object.customer_id)
        return if pay_customer.nil?

        pay_payment_method = pay_customer.payment_methods.where(processor_id: object.id).first_or_initialize
        pay_payment_method.update!(extract_attributes(object).merge(square_account: pay_customer.square_account))
        pay_payment_method
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        if try >= retries
          raise
        else
          sleep 0.15**(try + 1)
          sync(card_id, object: object, pay_customer: pay_customer, try: try + 1, retries: retries)
        end
      end

      def self.extract_attributes(card)
        {
          payment_method_type: "card",
          brand: card.card_brand,
          last4: card.last_4.to_s,
          exp_month: card.exp_month.to_s,
          exp_year: card.exp_year.to_s
        }
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_square_payment_method, Pay::Square::PaymentMethod
