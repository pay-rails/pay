# frozen_string_literal: true

require "rails/generators/active_record"
require "generators/pay/orm_helpers"

module ActiveRecord
  module Generators
    class MerchantGenerator < ActiveRecord::Generators::Base
      include Pay::Generators::OrmHelpers
      source_root File.expand_path("../templates", __FILE__)

      def copy_pay_merchant_migration
        if (behavior == :invoke && model_exists?) || (behavior == :revoke && migration_exists?(table_name))
          migration_template "merchant_migration.rb", "#{migration_path}/add_pay_merchant_to_#{table_name}.rb", migration_version: migration_version
        else
          say "#{model_path} does not exist.", :red
          say "⚠️  Make sure the #{name} model exists before running this generator."
        end
      end

      # If the file already contains the contents, the user will receive this warning:
      #
      #   File unchanged! The supplied flag value not found!
      #
      # This can be ignored as it just means the contents already exist and the file is unchanged.
      # Thor will be updated to improve this message: https://github.com/rails/thor/issues/706
      def inject_pay_merchant_content
        return unless model_exists?

        content = model_contents
        class_path = (namespaced? ? class_name.to_s.split("::") : [class_name])
        indent_depth = class_path.size - 1
        content = content.split("\n").map { |line| "  " * indent_depth + line }.join("\n") << "\n"
        inject_into_class(model_path, class_path.last, content)
      end

      private

      def model_contents
        "  include Pay::Merchant"
      end
    end
  end
end
