# frozen_string_literal: true

require "rails/generators/named_base"

module Pay
  module Generators
    class MerchantGenerator < Rails::Generators::NamedBase
      include Rails::Generators::ResourceHelpers

      source_root File.expand_path("../templates", __FILE__)

      desc "Generates a migration to add Pay::Merchant fields to a model."

      hook_for :orm
    end
  end
end
