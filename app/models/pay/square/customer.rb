module Pay
  module Square
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::Square::Charge"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::Square::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::Square::PaymentMethod"

      def api_record_attributes
        attributes = case owner.class.pay_square_customer_attributes
        when Symbol
          owner.send(owner.class.pay_square_customer_attributes, self)
        when Proc
          owner.class.pay_square_customer_attributes.call(self)
        end
        attributes ||= {}

        {email_address: email, given_name: customer_name}.compact.merge(attributes)
      end

      def api_record
        if processor_id?
          Pay::Square.with_client(self) { |client| client.customers.get(customer_id: processor_id) }.customer
        else
          result = Pay::Square.with_client(self) { |client| client.customers.create(**api_record_attributes) }.customer
          update!(processor_id: result.id)
          result
        end
      end

      # Pass a stable idempotency_key (e.g. keyed on the order) to make app-level resubmits
      # dedupe; otherwise a generated key covers only this call and its 401 retry.
      def charge(amount, options = {})
        options = options.dup
        idempotency_key = options.delete(:idempotency_key) || SecureRandom.uuid
        currency = (options.delete(:currency) || "usd").to_s.upcase
        source_id = options.delete(:source_id) || options.delete(:payment_method_id) || default_payment_method&.processor_id
        raise Pay::Square::Error, "No source_id or default payment method for Square charge" if source_id.blank?

        params = {
          idempotency_key: idempotency_key,
          source_id: source_id,
          amount_money: {amount: amount, currency: currency},
          customer_id: processor_id || api_record.id
        }
        if (app_fee = options.delete(:application_fee_amount) || options.delete(:app_fee_amount))
          params[:app_fee_money] = {amount: app_fee, currency: currency}
        end
        params.merge!(options)

        payment = Pay::Square.with_client(self) { |client| client.payments.create(**params) }.payment
        Pay::Square::Charge.sync(payment.id, object: payment, pay_customer: self)
      end

      # source_id is a single-use nonce minted client-side by Square's Web Payments SDK.
      def add_payment_method(source_id, default: false)
        api_record unless processor_id?
        idempotency_key = SecureRandom.uuid

        card = Pay::Square.with_client(self) do |client|
          client.cards.create(idempotency_key: idempotency_key, source_id: source_id, card: {customer_id: processor_id})
        end.card

        save_payment_method(card, default: default)
      end

      def update_payment_method(source_id)
        add_payment_method(source_id, default: true)
      end

      def save_payment_method(card, default:)
        pay_payment_method = payment_methods.where(processor_id: card.id).first_or_initialize

        attributes = Pay::Square::PaymentMethod.extract_attributes(card).merge(default: default, square_account: square_account)

        payment_methods.where.not(id: pay_payment_method.id).update_all(default: false) if default
        pay_payment_method.update!(attributes)

        reload_default_payment_method
        pay_payment_method
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_square_customer, Pay::Square::Customer
