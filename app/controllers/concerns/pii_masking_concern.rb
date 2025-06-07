module PiiMaskingConcern
  extend ActiveSupport::Concern

  private

  def validate_pii_response(data)
    return data unless current_user&.pii_masking_enabled?

    PiiMaskingValidationService.validate_agent_access(current_user, data)
  end

  def log_pii_access(action, resource_type, resource_id = nil)
    return unless current_user&.pii_masking_enabled?

    Rails.logger.info(
      "[PII_MASKING] #{action.upcase} attempt by user #{current_user.id} " \
      "(#{current_user.email}) on #{resource_type}" \
      "#{resource_id ? " ##{resource_id}" : ''}"
    )
  end
end
