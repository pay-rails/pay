class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :first_name
      t.string :last_name
      t.text :extra_billing_info
    end

    create_table :teams do |t|
      t.string :email
      t.string :name
      t.references :owner, polymorphic: true
    end

    create_table :accounts do |t|
      t.string :email
      t.string :merchant_processor
      t.string :pay_data
    end
  end
end
