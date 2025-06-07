class AddPiiMaskingEnabledToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :pii_masking_enabled, :boolean, default: false, null: false
    add_index :users, :pii_masking_enabled
  end
end
