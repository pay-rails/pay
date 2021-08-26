module Pay
  class ApplicationRecord < Pay.model_parent_class.constantize
    self.abstract_class = true
    self.table_name_prefix = "pay_"
  end
end
