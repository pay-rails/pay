module Pay
  module Paddle
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

      # Retrieves a Paddle::Customer object
      #
      # Finds an existing Paddle::Customer if processor_id exists
      # Creates a new Paddle::Customer using `email` and `customer_name` if empty processor_id
      #
      # Returns a Paddle::Customer object
      def customer
        if processor_id?
          ::Paddle::Customer.retrieve(id: processor_id)
        else
          sc = ::Paddle::Customer.create(email: email, name: customer_name)
          pay_customer.update!(processor_id: sc.id)
          sc
        end
      rescue ::Paddle::Error => e
        raise Pay::Paddle::Error, e
      end

      # Syncs name and email to Paddle::Customer
      # You can also pass in other attributes that will be merged into the default attributes
      def update_customer!(**attributes)
        customer unless processor_id?
        attrs = customer_attributes.merge(attributes)
        ::Paddle::Customer.update(id: processor_id, **attrs)
      end

      def charge(amount, options = {})
        subscription = pay_customer.subscription
        return unless subscription.processor_id
        raise Pay::Error, "A charge_name is required to create a one-time charge" if options[:charge_name].nil?

        response = PaddlePay::Subscription::Charge.create(subscription.processor_id, amount.to_f / 100, options[:charge_name], options)

        attributes = {
          amount: (response[:amount].to_f * 100).to_i,
          paddle_receipt_url: response[:receipt_url],
          created_at: Time.zone.parse(response[:payment_date])
        }

        # Lookup subscription payment method details
        attributes.merge! Pay::Paddle::PaymentMethod.payment_method_details_for(subscription_id: subscription.processor_id)

        charge = pay_customer.charges.find_or_initialize_by(processor_id: response[:invoice_id])
        charge.update(attributes)
        charge
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # pass
      end

      # Paddle does not use payment method tokens. The method signature has it here
      # to have a uniform API with the other payment processors.
      def add_payment_method(token = nil, default: true)
        Pay::Paddle::PaymentMethod.sync(pay_customer: pay_customer)
      end

      def trial_end_date(subscription)
        return unless subscription.state == "trialing"
        Time.zone.parse(subscription.next_payment[:date]).end_of_day
      end

      def processor_subscription(subscription_id, options = {})
        hash = PaddlePay::Subscription::User.list({subscription_id: subscription_id}, options).try(:first)
        OpenStruct.new(hash)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end
    end
  end
end
