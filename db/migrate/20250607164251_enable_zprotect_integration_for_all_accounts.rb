class EnableZprotectIntegrationForAllAccounts < ActiveRecord::Migration[7.0]
  def up
    # Enable zprotect_integration for all existing accounts in batches of 100
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.enable_features!('zprotect_integration') }
    end

    # Clear global config cache to ensure changes are propagated
    GlobalConfig.clear_cache
  end

  def down
    # Disable zprotect_integration for all accounts if needed to rollback
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.disable_features!('zprotect_integration') }
    end

    # Clear global config cache to ensure changes are propagated
    GlobalConfig.clear_cache
  end
end
