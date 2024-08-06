module Pay
  module LemonSqueezy
    class Billable
      attr_reader :pay_customer

      delegate :processor_id,
        :processor_id?,
        :email,
        :customer_name,
        :card_token,
        to: :pay_customer

      def initialize(pay_customer)
        @pay_customer = pay_customer
      end

      def customer_attributes
        {email: email, name: customer_name}
      end

      # Retrieves a LemonSqueezy::Customer object
      #
      # Finds an existing LemonSqueezy::Customer if processor_id exists
      # Creates a new LemonSqueezy::Customer using `email` and `customer_name` if empty processor_id
      #
      # Returns a LemonSqueezy::Customer object
      def customer
        if processor_id?
          ::LemonSqueezy::Customer.retrieve(id: processor_id)
        else
          sc = ::LemonSqueezy::Customer.create(store_id: Pay::LemonSqueezy.store_id, email: email, name: customer_name)
          pay_customer.update!(processor_id: sc.id)
          sc
        end
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end

      # Syncs name and email to LemonSqueezy::Customer
      # You can also pass in other attributes that will be merged into the default attributes
      def update_customer!(**attributes)
        customer unless processor_id?
        attrs = customer_attributes.merge(attributes)
        ::LemonSqueezy::Customer.update(id: processor_id, **attrs)
      end

      def charge(amount, options = {})
        raise Pay::Error, "LemonSqueezy does not support one-off charges"
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # pass
      end

      def add_payment_method(token = nil, default: true)
        # pass
      end

      def trial_end_date(subscription)
        return unless subscription.state == "on-trial"
        Time.zone.parse(subscription.renews_at).end_of_day
      end

      def processor_subscription(subscription_id, options = {})
        ::LemonSqueezy::Subscription.retrieve(id: subscription_id)
      rescue ::LemonSqueezy::Error => e
        raise Pay::LemonSqueezy::Error, e
      end
    end
  end
end
