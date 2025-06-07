class PiiMaskingValidationService
  include Rails.application.routes.url_helpers

  def self.validate_agent_access(user, contact_data)
    return contact_data unless user&.pii_masking_enabled?

    new(user, contact_data).validate_and_sanitize
  end

  def initialize(user, contact_data)
    @user = user
    @contact_data = contact_data
    @violations = []
  end

  def validate_and_sanitize
    log_access_attempt
    sanitized_data = sanitize_contact_data(@contact_data)
    log_violations if @violations.any?
    sanitized_data
  end

  private

  attr_reader :user, :contact_data, :violations

  def sanitize_contact_data(data)
    case data
    when Hash
      sanitize_hash(data)
    when Array
      data.map { |item| sanitize_contact_data(item) }
    else
      data
    end
  end

  def sanitize_hash(hash)
    hash.deep_dup.tap do |sanitized|
      sanitized.each do |key, value|
        if pii_field?(key)
          sanitize_pii_field(sanitized, key, value)
        elsif value.is_a?(Hash) || value.is_a?(Array)
          sanitized[key] = sanitize_contact_data(value)
        end
      end
    end
  end

  def pii_field?(key)
    key.to_s.in?(%w[email phone_number phone phone_number_formatted])
  end

  def sanitize_pii_field(sanitized, key, value)
    return if value.blank?

    add_violation(key, value)
    sanitized[key] = '[PROTECTED]'
  end

  def add_violation(field, value)
    @violations << {
      field: field,
      value_hash: Digest::SHA256.hexdigest(value.to_s),
      timestamp: Time.current
    }
  end

  def log_access_attempt
    Rails.logger.info(
      "[PII_MASKING] Access attempt by user #{user.id} (#{user.email}) - " \
      "PII masking enabled: #{user.pii_masking_enabled?}"
    )
  end

  def log_violations
    Rails.logger.warn(
      "[PII_MASKING] PII data sanitized for user #{user.id} - " \
      "Violations: #{violations.length} fields"
    )

    # In production, this could be sent to an audit logging service
    violations.each do |violation|
      Rails.logger.warn(
        "[PII_MASKING] Field '#{violation[:field]}' sanitized - " \
        "Value hash: #{violation[:value_hash][0..10]}..."
      )
    end
  end
end
