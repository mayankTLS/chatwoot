# frozen_string_literal: true

# Concern for handling sensitive data masking functionality
module Maskable
  extend ActiveSupport::Concern

  included do
    # Include masking functionality in models that have sensitive data
  end

  # Masks an email address based on account settings and user permissions
  # @param email [String] The email address to mask
  # @param current_user [User] The user requesting the data
  # @param account [Account] The account context
  # @return [String] Masked or original email
  def mask_email_for_user(email, current_user, account)
    should_mask = should_mask_for_user?(current_user, account, 'email')
    
    # Log data access for audit purposes
    if email.present? && should_mask
      log_sensitive_data_access(current_user, account, 'email', 'masked_view')
    end
    
    return email unless should_mask

    mask_email_value(email, account.masking_pattern_for('email'))
  end

  # Masks a phone number based on account settings and user permissions
  # @param phone [String] The phone number to mask
  # @param current_user [User] The user requesting the data
  # @param account [Account] The account context
  # @return [String] Masked or original phone number
  def mask_phone_for_user(phone, current_user, account)
    should_mask = should_mask_for_user?(current_user, account, 'phone')
    
    # Log data access for audit purposes
    if phone.present? && should_mask
      log_sensitive_data_access(current_user, account, 'phone', 'masked_view')
    end
    
    return phone unless should_mask

    mask_phone_value(phone, account.masking_pattern_for('phone'))
  end

  private

  # Determines if data should be masked for a specific user
  # @param user [User] The user requesting the data
  # @param account [Account] The account context
  # @param data_type [String] Type of data ('email' or 'phone')
  # @return [Boolean] Whether data should be masked
  def should_mask_for_user?(user, account, data_type)
    return false unless account&.feature_enabled?(:data_masking)
    return false unless account&.masking_enabled?
    return false unless account.masking_enabled_for?(data_type)
    return false if account.user_can_bypass_masking?(user)

    true
  end

  # Masks an email address using the specified pattern
  # @param email [String] The email to mask
  # @param pattern [String] The masking pattern ('minimal', 'standard', 'complete')
  # @return [String] Masked email
  def mask_email_value(email, pattern = 'standard')
    return email unless email&.include?('@')

    local_part, domain = email.split('@', 2)

    case pattern
    when 'minimal'
      "#{local_part.first}***@#{domain}"
    when 'standard'
      if local_part.length <= 2
        "***@#{domain}"
      else
        "#{local_part.first}***#{local_part.last}@#{mask_domain(domain)}"
      end
    when 'complete'
      '*** HIDDEN ***'
    else
      "***@#{domain}"
    end
  end

  # Masks a phone number using the specified pattern
  # @param phone [String] The phone to mask
  # @param pattern [String] The masking pattern ('minimal', 'standard', 'complete')
  # @return [String] Masked phone number
  def mask_phone_value(phone, pattern = 'standard')
    return phone unless phone

    # Extract digits only for processing
    digits = phone.gsub(/\D/, '')
    return phone if digits.empty?

    case pattern
    when 'minimal'
      # Show country code and last 4 digits
      if digits.length <= 4
        '***'
      else
        last_four = digits.last(4)
        country_code = digits.start_with?('1') ? '+1' : '+**'
        "#{country_code} ***-***-#{last_four}"
      end
    when 'standard'
      # Show last 4 digits
      if digits.length <= 4
        '***'
      else
        last_four = digits.last(4)
        "***-***-#{last_four}"
      end
    when 'complete'
      '*** HIDDEN ***'
    else
      if digits.length <= 4
        '***'
      else
        "***-***-#{digits.last(4)}"
      end
    end
  end

  # Masks domain name partially
  # @param domain [String] The domain to mask
  # @return [String] Masked domain
  def mask_domain(domain)
    parts = domain.split('.')
    return domain if parts.length < 2

    masked_parts = parts.map.with_index do |part, index|
      # Keep the TLD (last part) visible
      if index == parts.length - 1
        part
      elsif part.length <= 3
        '***'
      else
        "#{part.first}***"
      end
    end

    masked_parts.join('.')
  end

  # Logs sensitive data access for audit purposes
  # @param user [User] The user accessing the data
  # @param account [Account] The account context
  # @param data_type [String] Type of data ('email' or 'phone')
  # @param action [String] Action performed ('masked_view', 'revealed', 'copied')
  def log_sensitive_data_access(user, account, data_type, action)
    return unless Rails.env.production? || Rails.env.development?

    context = {
      action: action,
      model: self.class.name,
      model_id: respond_to?(:id) ? id : nil
    }

    AuditLog::MaskingAuditService.log_data_access(
      user: user,
      account: account,
      event: action == 'revealed' ? 'data_revealed' : 'data_viewed',
      data_type: data_type,
      context: context
    )
  rescue StandardError => e
    # Don't let audit logging failures break the application
    Rails.logger.error "Failed to log sensitive data access: #{e.message}"
  end
end