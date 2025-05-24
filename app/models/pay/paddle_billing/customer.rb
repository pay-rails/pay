module Pay
  module PaddleBilling
    class Customer < Pay::Customer
      has_many :pay_charges, dependent: :destroy, class_name: "Pay::PaddleBilling::Charge"
      has_many :pay_subscriptions, dependent: :destroy, class_name: "Pay::PaddleBilling::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::PaddleBilling::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::PaddleBilling::PaymentMethod"

      def api_record_attributes
        {email: email, name: customer_name}
      end

      # Retrieves a Paddle::Customer object
      #
      # Finds an existing Paddle::Customer if processor_id exists
      # Creates a new Paddle::Customer using `email` and `customer_name` if empty processor_id
      #
      # Returns a Paddle::Customer object
      def api_record
        if processor_id?
          ::Paddle::Customer.retrieve(id: processor_id)
        elsif (pc = ::Paddle::Customer.list(email: email).data&.first)
          update!(processor_id: pc.id)
          pc
        else
          pc = ::Paddle::Customer.create(email: email, name: customer_name)
          update!(processor_id: pc.id)
          pc
        end
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      # Syncs name and email to Paddle::Customer
      # You can also pass in other attributes that will be merged into the default attributes
      def update_api_record(**attributes)
        api_record unless processor_id?
        ::Paddle::Customer.update(id: processor_id, **api_record_attributes.merge(attributes))
      end

      def charge(amount, options = {})
        return Pay::Error unless options

        items = options[:items]
        opts = options.except(:items).merge(customer_id: processor_id)
        transaction = ::Paddle::Transaction.create(items: items, **opts)

        attrs = {
          amount: transaction.details.totals.grand_total,
          created_at: transaction.created_at,
          currency: transaction.currency_code,
          metadata: transaction.details.line_items&.first&.id
        }

        charge = pay_charges.find_or_initialize_by(processor_id: transaction.id)
        charge.update(attrs)
        charge
      rescue ::Paddle::Error => e
        raise Pay::PaddleBilling::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # pass
      end

      # Paddle does not use payment method tokens. The method signature has it here
      # to have a uniform API with the other payment processors.
      def add_payment_method(token = nil, default: true)
        Pay::PaddleBilling::PaymentMethod.sync(pay_customer: self)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_paddle_billing_customer, Pay::PaddleBilling::Customer
