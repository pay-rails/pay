module Pay
  module AwsMarketplace
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::AwsMarketplace::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::AwsMarketplace::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::AwsMarketplace::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::AwsMarketplace::PaymentMethod"

      def api_record
        update!(processor_id: NanoId.generate) unless processor_id?
        self
      end

      def update_api_record(**attributes)
        self
      end

      def charge(amount, options = {})
        raise Pay::Error, "AWS Marketplace does not support one-off charges"
      end

      # https://stripe.com/docs/api/checkout/sessions/create
      #
      # checkout(mode: "payment")
      # checkout(mode: "setup")
      # checkout(mode: "subscription")
      #
      # checkout(line_items: "price_12345", quantity: 2)
      # checkout(line_items: [{ price: "price_123" }, { price: "price_456" }])
      # checkout(line_items: "price_12345", allow_promotion_codes: true)
      #
      def checkout(**options)
        api_record unless processor_id?
        args = {
          customer: processor_id,
          mode: "payment"
        }

        # Hosted (the default) checkout sessions require a success_url and cancel_url
        if ["", "hosted"].include? options[:ui_mode].to_s
          args[:success_url] = merge_session_id_param(options.delete(:success_url) || root_url)
          args[:cancel_url] = merge_session_id_param(options.delete(:cancel_url) || root_url)
        end

        if options[:return_url]
          args[:return_url] = merge_session_id_param(options.delete(:return_url))
        end

        # Line items are optional
        if (line_items = options.delete(:line_items))
          quantity = options.delete(:quantity) || 1

          args[:line_items] = Array.wrap(line_items).map { |item|
            if item.is_a? Hash
              item
            else
              {
                price: item,
                quantity: quantity
              }
            end
          }
        end

        ::Stripe::Checkout::Session.create(args.merge(options), stripe_options)
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # Make to generate a processor_id
        api_record
        attributes = options.merge(
          processor_id: NanoId.generate,
          name: name,
          processor_plan: plan,
          status: :active,
          quantity: options.fetch(:quantity, 1)
        )

        if (trial_period_days = attributes.delete(:trial_period_days))
          attributes[:trial_ends_at] = trial_period_days.to_i.days.from_now
        end

        attributes.delete(:promotion_code)

        subscriptions.create!(attributes)
      end

      def add_payment_method(payment_method_id, default: false)
        # Make to generate a processor_id
        api_record

        pay_payment_method = payment_methods.create!(
          processor_id: NanoId.generate,
          default: default,
          payment_method_type: :card,
          data: {
            brand: "AWS",
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        )

        if default
          payment_methods.where.not(id: pay_payment_method.id).update_all(default: false)
          reload_default_payment_method
        end

        pay_payment_method
      end
    end
  end
end
