module Pay
  module LemonSqueezy
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::LemonSqueezy::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::LemonSqueezy::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::LemonSqueezy::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::LemonSqueezy::PaymentMethod"

      def api_record_attributes
        {email: email, name: customer_name}
      end

      # Retrieves a LemonSqueezy::Customer object
      #
      # Finds an existing LemonSqueezy::Customer if processor_id exists
      # Creates a new LemonSqueezy::Customer using `email` and `customer_name` if empty processor_id
      #
      # Returns a LemonSqueezy::Customer object
      def api_record
        if processor_id?
          ::LemonSqueezy::Customer.retrieve(id: processor_id)
        else
          lsc = ::LemonSqueezy::Customer.create(store_id: Pay::LemonSqueezy.store_id, **api_record_attributes)
          update!(processor_id: lsc.id)
          lsc
        end
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      # Syncs name and email to LemonSqueezy::Customer
      # You can also pass in other attributes that will be merged into the default attributes
      def update_api_record(**attributes)
        api_record unless processor_id?
        ::LemonSqueezy::Customer.update(id: processor_id, **api_record_attributes.merge(attributes))
      end

      def charge(amount, options = {})
        raise Pay::Error, "LemonSqueezy does not support one-off charges"
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
      end

      def add_payment_method(token = nil, default: true)
      end
    end
  end
end
