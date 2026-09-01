class AddSquareAccountToPayModels < ActiveRecord::Migration[6.0]
  # Scopes a Pay::Customer / PaymentMethod / Charge to a Square merchant (mirrors
  # stripe_account). Existing apps: run `bin/rails pay:install:migrations && db:migrate`.
  def change
    add_column :pay_customers, :square_account, :string
    add_column :pay_payment_methods, :square_account, :string
    add_column :pay_charges, :square_account, :string
  end
end
