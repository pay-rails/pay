# frozen_string_literal: true

require "rails/generators/active_record"
require "generators/pay/orm_helpers"

module ActiveRecord
  module Generators
    class PayGenerator < ActiveRecord::Generators::Base
      include Pay::Generators::OrmHelpers
      source_root File.expand_path("../templates", __FILE__)

      def copy_pay_billable_migration
        if (behavior == :invoke && model_exists?) || (behavior == :revoke && migration_exists?(table_name))
          migration_template "migration.rb", "#{migration_path}/add_pay_billable_to_#{table_name}.rb", migration_version: migration_version
        end
        # TODO: Throw error here that model should already exist if it doesn't
      end

      def inject_pay_billable_content
        content = model_contents

        class_path = if namespaced?
          class_name.to_s.split("::")
        else
          [class_name]
        end

        indent_depth = class_path.size - 1
        content = content.split("\n").map { |line| "  " * indent_depth + line }.join("\n") << "\n"

        inject_into_class(model_path, class_path.last, content) if model_exists?
      end

      def migration_data
        <<RUBY
      t.string :processor
      t.string :processor_id
      t.datetime :trial_ends_at
      t.string :card_type
      t.string :card_last4
      t.string :card_exp_month
      t.string :card_exp_year
      t.text :extra_billing_info
RUBY
      end

      def rails5_and_up?
        Rails::VERSION::MAJOR >= 5
      end

      def migration_version
        if rails5_and_up?
          "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        end
      end
    end
  end
end
