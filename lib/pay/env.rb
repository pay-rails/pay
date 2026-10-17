module Pay
  module Env
    # Declares the credentials a processor reads. Each gets a reader that looks the value up in this order:
    #
    #   ENV["STRIPE_PRIVATE_KEY"]
    #   Rails.application.credentials.dig(:production, :stripe, :private_key)
    #   Rails.application.credentials.dig(:stripe, :private_key)
    #
    # The readers live in an extended module, so a processor refines one with super (for a default, say).
    # They are plain methods, not closures, so a Ractor can call them.
    def credential(*names)
      credential_names.concat(names)

      readers = Module.new
      names.each do |name|
        readers.module_eval("def #{name}; find_value_by_name(:#{name}); end", __FILE__, __LINE__)
      end
      extend readers
    end

    # Resolves every declared credential once and serves the frozen values from then on, so a Ractor never has to
    # read ENV or the Rails credentials. Pay.make_shareable! calls this before Rails shares the application.
    def freeze_credentials!
      @frozen_credentials = Pay.make_shareable(credential_names.to_h { |name| [name, find_value_by_name(name)] })
    end

    private

    def credential_names
      @credential_names ||= []
    end

    def find_value_by_name(name)
      return @frozen_credentials.fetch(name) if @frozen_credentials

      ENV["#{credential_scope.upcase}_#{name.upcase}"] ||
        credentials&.dig(env, credential_scope, name) ||
        credentials&.dig(credential_scope, name)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      Rails.logger.error <<~MESSAGE
        Rails was unable to decrypt credentials. Pay checks the Rails credentials to look for API keys for payment processors.

        Make sure to set the `RAILS_MASTER_KEY` env variable or in the .key file. To learn more, run "bin/rails credentials:help"

        If you're not using Rails credentials, you can delete `config/credentials.yml.enc` and `config/credentials/`.
      MESSAGE
    end

    # Pay::PaddleBilling reads :paddle_billing credentials
    def credential_scope
      name.demodulize.underscore.to_sym
    end

    def env
      Rails.env.to_sym
    end

    def credentials
      Rails.application.credentials if Rails.application.respond_to?(:credentials)
    end
  end
end
