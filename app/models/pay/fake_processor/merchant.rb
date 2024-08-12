module Pay
  module FakeProcessor
    class Merchant < Pay::Merchant
      def create_account(**options)
        fake_account = Struct.new(:id).new("fake_account_id")
        update(processor_id: fake_account.id)
        fake_account
      end

      def account_link(refresh_url:, return_url:, type: "account_onboarding", **options)
        Struct.new(:url).new("/fake_processor/account_link")
      end

      def login_link(**options)
        Struct.new(:url).new("/fake_processor/login_link")
      end
    end
  end
end
