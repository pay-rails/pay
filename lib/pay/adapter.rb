module Pay
  module Adapter
    extend ActiveSupport::Concern

    def self.current_adapter
      ActiveRecord::Base.connection_db_config.adapter
    end

    def self.json_column_type
      case current_adapter
      when "postgresql"
        :jsonb
      else
        :json
      end
    end
  end
end
