module Pay
  module LemonSqueezy
    class Customer < Pay::Customer
      include Pay::Routing

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
        elsif (lsc = ::LemonSqueezy::Customer.list(store_id: Pay::LemonSqueezy.store_id, email: email).data.first)
          update!(processor_id: lsc.id)
          lsc
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

      # checkout(variant_id: "1234")
      # checkout(variant_id: "1234", product_options: {redirect_url: redirect_url})
      def checkout(**options)
        api_record unless processor_id?

        options[:store_id] = Pay::LemonSqueezy.store_id
        options[:product_options] ||= {}
        options[:product_options][:redirect_url] = merge_order_id_param(options.dig(:product_options, :redirect_url) || root_url)

        ::LemonSqueezy::Checkout.create(**options)
      end

      def portal_url
        api_record.urls.customer_portal
      end

      private

      def merge_order_id_param(url)
        uri = URI.parse(url)
        uri.query = URI.encode_www_form(URI.decode_www_form(uri.query.to_s).to_h.merge("lemon_squeezy_order_id" => "[order_id]").to_a)
        uri.to_s.gsub("%5Border_id%5D", "[order_id]")
      end
    end
  end
end
