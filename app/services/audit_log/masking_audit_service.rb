# frozen_string_literal: true

# Service for logging sensitive data access for audit purposes
class AuditLog::MaskingAuditService
  include ActionView::Helpers::DateHelper

  EVENTS = {
    data_revealed: 'data_revealed',
    data_copied: 'data_copied',
    settings_updated: 'masking_settings_updated',
    feature_enabled: 'masking_feature_enabled',
    feature_disabled: 'masking_feature_disabled'
  }.freeze

  def self.log_data_access(user:, account:, event:, data_type:, context: {})
    new.log_data_access(
      user: user,
      account: account,
      event: event,
      data_type: data_type,
      context: context
    )
  end

  def self.log_settings_change(user:, account:, old_settings:, new_settings:)
    new.log_settings_change(
      user: user,
      account: account,
      old_settings: old_settings,
      new_settings: new_settings
    )
  end

  def self.log_feature_toggle(user:, account:, enabled:)
    new.log_feature_toggle(
      user: user,
      account: account,
      enabled: enabled
    )
  end

  def log_data_access(user:, account:, event:, data_type:, context: {})
    return unless should_log_event?(event)
    return unless valid_data_type?(data_type)

    log_entry = build_log_entry(
      user: user,
      account: account,
      event: event,
      details: {
        data_type: data_type,
        timestamp: Time.current.iso8601,
        context: context.slice(:contact_id, :conversation_id, :message_id, :action)
      }
    )

    write_audit_log(log_entry)
  end

  def log_settings_change(user:, account:, old_settings:, new_settings:)
    changes = compute_settings_changes(old_settings, new_settings)
    return if changes.empty?

    log_entry = build_log_entry(
      user: user,
      account: account,
      event: EVENTS[:settings_updated],
      details: {
        changes: changes,
        timestamp: Time.current.iso8601
      }
    )

    write_audit_log(log_entry)
  end

  def log_feature_toggle(user:, account:, enabled:)
    event = enabled ? EVENTS[:feature_enabled] : EVENTS[:feature_disabled]
    
    log_entry = build_log_entry(
      user: user,
      account: account,
      event: event,
      details: {
        feature: 'data_masking',
        enabled: enabled,
        timestamp: Time.current.iso8601
      }
    )

    write_audit_log(log_entry)
  end

  private

  def should_log_event?(event)
    EVENTS.values.include?(event.to_s)
  end

  def valid_data_type?(data_type)
    %w[email phone].include?(data_type.to_s)
  end

  def build_log_entry(user:, account:, event:, details:)
    {
      event: event,
      actor: {
        type: 'User',
        id: user&.id,
        email: user&.email,
        name: user&.name,
        role: user_role(user, account)
      },
      target: {
        type: 'Account',
        id: account&.id,
        name: account&.name
      },
      details: details,
      metadata: {
        ip_address: Current.ip_address,
        user_agent: Current.user_agent,
        source: 'masking_system'
      }
    }
  end

  def user_role(user, account)
    return 'unknown' unless user && account

    account_user = account.account_users.find_by(user: user)
    account_user&.role || 'unknown'
  end

  def compute_settings_changes(old_settings, new_settings)
    changes = {}
    
    old_settings = normalize_settings(old_settings)
    new_settings = normalize_settings(new_settings)

    # Check top-level changes
    if old_settings[:masking_enabled] != new_settings[:masking_enabled]
      changes[:masking_enabled] = {
        from: old_settings[:masking_enabled],
        to: new_settings[:masking_enabled]
      }
    end

    # Check rule changes
    old_rules = old_settings[:masking_rules] || {}
    new_rules = new_settings[:masking_rules] || {}

    rule_changes = compute_rule_changes(old_rules, new_rules)
    changes[:masking_rules] = rule_changes unless rule_changes.empty?

    changes
  end

  def compute_rule_changes(old_rules, new_rules)
    changes = {}

    # Check email rules
    if old_rules[:email] != new_rules[:email]
      changes[:email] = {
        from: old_rules[:email],
        to: new_rules[:email]
      }
    end

    # Check phone rules
    if old_rules[:phone] != new_rules[:phone]
      changes[:phone] = {
        from: old_rules[:phone],
        to: new_rules[:phone]
      }
    end

    # Check permission changes
    permission_fields = [:admin_bypass, :allow_reveal, :exempt_roles]
    permission_fields.each do |field|
      if old_rules[field] != new_rules[field]
        changes[field] = {
          from: old_rules[field],
          to: new_rules[field]
        }
      end
    end

    changes
  end

  def normalize_settings(settings)
    return {} unless settings

    settings = settings.deep_symbolize_keys if settings.respond_to?(:deep_symbolize_keys)
    settings = settings.with_indifferent_access

    {
      masking_enabled: settings[:masking_enabled] || false,
      masking_rules: settings[:masking_rules] || {}
    }
  end

  def write_audit_log(log_entry)
    if Rails.env.development?
      Rails.logger.info "MASKING_AUDIT: #{log_entry.to_json}"
    end

    # In production, you would typically:
    # 1. Write to a dedicated audit log table
    # 2. Send to external logging service (e.g., Datadog, Splunk)
    # 3. Write to secure log files
    # 4. Send to SIEM system

    # Example implementations:
    write_to_audit_table(log_entry) if should_write_to_database?
    send_to_external_service(log_entry) if should_send_to_external_service?
  end

  def write_to_audit_table(log_entry)
    # Example: Create an audit log record
    # This would require creating an audit_logs table
    # AuditLog.create!(
    #   event_type: log_entry[:event],
    #   actor_type: log_entry[:actor][:type],
    #   actor_id: log_entry[:actor][:id],
    #   target_type: log_entry[:target][:type],
    #   target_id: log_entry[:target][:id],
    #   details: log_entry[:details],
    #   metadata: log_entry[:metadata],
    #   created_at: Time.current
    # )
  end

  def send_to_external_service(log_entry)
    # Example: Send to external audit service
    # ExternalAuditService.send_log(log_entry)
    
    # Example: Send to webhook
    # webhook_url = GlobalConfig.get('AUDIT_WEBHOOK_URL')
    # if webhook_url.present?
    #   Net::HTTP.post(URI(webhook_url), log_entry.to_json, 'Content-Type' => 'application/json')
    # end
  end

  def should_write_to_database?
    # Check if audit logging to database is enabled
    GlobalConfig.get('ENABLE_DATABASE_AUDIT_LOGS')&.to_s == 'true'
  end

  def should_send_to_external_service?
    # Check if external audit logging is configured
    GlobalConfig.get('AUDIT_WEBHOOK_URL').present? || 
    GlobalConfig.get('EXTERNAL_AUDIT_SERVICE_ENABLED')&.to_s == 'true'
  end
end