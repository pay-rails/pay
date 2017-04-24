require 'activemodel/associations'

class User
  include ActiveModel::Model
  include ActiveModel::Associations

  # need hash like accessor, used internal Rails
  def [](attr)
    self.send(attr)
  end

  # need hash like accessor, used internal Rails
  def []=(attr, value)
    self.send("#{attr}=", value)
  end

  include Pay::Billable
end
