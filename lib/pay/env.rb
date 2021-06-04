module Pay
  module Env
    private

    # Search for environment variables
    #
    # We must handle a lot of different cases, including the new Rails 6
    # environment separated credentials files which have no nesting for
    # the current environment.
    #
    # 1. Check environment variable
    # 2. Check environment scoped credentials, then secrets
    # 3. Check unscoped credentials, then secrets
    def find_value_by_name(scope, name)
      ENV["#{scope.upcase}_#{name.upcase}"] ||
        credentials&.dig(env, scope, name) ||
        secrets&.dig(env, scope, name) ||
        credentials&.dig(scope, name) ||
        secrets&.dig(scope, name)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      Rails.logger.error <<~MESSAGE
        Rails was unable to decrypt credentials. Pay checks the Rails credentials to look for API keys for payment processors.

        Make sure to set the `RAILS_MASTER_KEY` env variable or in the .key file. To learn more, run "bin/rails credentials:help"

        If you're not using Rails credentials, you can delete `config/credentials.yml.enc` and `config/credentials/`.
      MESSAGE
    end

    def env
      Rails.env.to_sym
    end

    def secrets
      Rails.application.secrets
    end

    def credentials
      Rails.application.credentials if Rails.application.respond_to?(:credentials)
    end
  end
end
