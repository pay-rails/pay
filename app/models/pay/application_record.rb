module Pay
  class ApplicationRecord < Pay.model_parent_class.constantize
    self.abstract_class = true
    self.table_name_prefix = "pay_"

    def self.json_column?(name)
      return unless connected? && table_exists?
      [:json, :jsonb].include?(attribute_types[name].type)
    end
  end
end
