# This migration comes from thinkspace_common (originally 20160601000000)
class AddLastSignInAtToThinkspaceCommonUsers < ActiveRecord::Migration

  def up
    change_table :thinkspace_common_users do |t|
      t.datetime :last_sign_in_at
    end
  end

  def down
    change_table :thinkspace_common_users do |t|
      t.remove :last_sign_in_at
    end
  end

end
