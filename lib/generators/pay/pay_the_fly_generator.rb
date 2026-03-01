# frozen_string_literal: true

require "rails/generators"

module Pay
  module Generators
    class PayTheFlyGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Generates a PayTheFly initializer for the Pay gem"

      def create_initializer
        template "pay_the_fly_initializer.rb", "config/initializers/pay_the_fly.rb"
      end

      def show_readme
        readme "PAY_THE_FLY_README" if behavior == :invoke
      end
    end
  end
end
