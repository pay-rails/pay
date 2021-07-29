class Pay::Customer < Pay::ApplicationRecord
  belongs_to :owner, polymorphic: true
end
