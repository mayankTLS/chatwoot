class AddDataMaskingFeatureFlag < ActiveRecord::Migration[7.0]
  def up
    # Add data_masking to ACCOUNT_LEVEL_FEATURE_DEFAULTS if it doesn't exist
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    if config && config.value.present?
      existing_feature = config.value.find { |f| f['name'] == 'data_masking' }
      
      unless existing_feature
        new_feature = {
          'name' => 'data_masking',
          'display_name' => 'Data Masking',
          'enabled' => true,
          'help_url' => 'https://chwt.app/hc/data-masking'
        }
        
        config.value = config.value + [new_feature]
        config.save!
      end
    else
      # If no config exists, create it with just the data masking feature
      # (In practice, this should be handled by ConfigLoader, but this is a safety net)
      InstallationConfig.create!(
        name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS',
        value: [{
          'name' => 'data_masking',
          'display_name' => 'Data Masking',
          'enabled' => true,
          'help_url' => 'https://chwt.app/hc/data-masking'
        }],
        locked: true
      )
    end

    # Enable data masking feature for all existing accounts
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.enable_features!('data_masking') }
    end

    # Set default masking settings for all accounts that don't have them
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each do |account|
        next if account.settings&.dig('masking')&.present?
        
        account.settings = (account.settings || {}).merge(
          'masking' => {
            'masking_enabled' => true,
            'masking_rules' => {
              'admin_bypass' => false,  # Don't bypass for admins by default
              'allow_reveal' => true,
              'exempt_roles' => [],     # No roles exempt by default
              'email' => { 'enabled' => true, 'pattern' => 'standard' },
              'phone' => { 'enabled' => true, 'pattern' => 'standard' }
            }
          }
        )
        account.save!
      end
    end

    # Clear global config cache to ensure changes are reflected
    GlobalConfig.clear_cache if defined?(GlobalConfig)
  end

  def down
    # Remove data_masking from ACCOUNT_LEVEL_FEATURE_DEFAULTS
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    if config && config.value.present?
      config.value = config.value.reject { |f| f['name'] == 'data_masking' }
      config.save!
    end

    # Clear global config cache
    GlobalConfig.clear_cache if defined?(GlobalConfig)
  end
end