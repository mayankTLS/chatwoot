class ZprotectService
  include HTTParty

  base_uri ENV.fetch('ZPROTECT_API_URL', nil)
  headers 'Content-Type' => 'application/json'
  default_timeout 30

  class << self
    def get_customer_orders(identifier:, identifier_type:, user_id: nil)
      Rails.logger.info "ZProtect: Fetching orders for #{mask_identifier(identifier, identifier_type)}"

      validate_identifier!(identifier, identifier_type)

      query_params = build_query_params(identifier, identifier_type)
      headers = build_headers(user_id)

      response = get('/orders', query: query_params, headers: headers)
      handle_response(response, "get orders for #{mask_identifier(identifier, identifier_type)}")
    end

    def cancel_order(order_id:, options: {}, user_id: nil)
      Rails.logger.info "ZProtect: Cancelling order #{order_id}"

      validate_order_id!(order_id)

      headers = build_headers(user_id)
      body = build_cancel_body(options)

      endpoint = "/orders/#{order_id}/cancel"
      response = post(endpoint, headers: headers, body: body.to_json)
      handle_response(response, "cancel order #{order_id}")
    end

    def refund_order(order_id:, refund_items:, options: {}, user_id: nil)
      Rails.logger.info "ZProtect: Processing refund for order #{order_id}"

      validate_order_id!(order_id)
      validate_refund_items!(refund_items)

      headers = build_headers(user_id)
      body = build_refund_body(refund_items, options)

      endpoint = "/orders/#{order_id}/refund"
      response = post(endpoint, headers: headers, body: body.to_json)
      handle_response(response, "refund order #{order_id}")
    end

    def health_check
      Rails.logger.debug 'ZProtect: Health check'

      response = get('/health')
      handle_response(response, 'health check')
    end

    def invalidate_cache(identifier:, identifier_type:, user_id: nil)
      Rails.logger.info "ZProtect: Invalidating cache for #{mask_identifier(identifier, identifier_type)}"

      validate_identifier!(identifier, identifier_type)

      headers = build_headers(user_id)
      body = { identifier_type => identifier }

      response = post('/orders/cache/invalidate', headers: headers, body: body.to_json)
      handle_response(response, "invalidate cache for #{mask_identifier(identifier, identifier_type)}")
    end

    private

    def build_headers(user_id = nil)
      api_key = ENV.fetch('ZPROTECT_API_KEY', nil)
      headers = {
        'x-auth-key' => api_key,
        'Content-Type' => 'application/json'
      }
      headers['x-user-id'] = user_id.to_s if user_id
      headers
    end

    def build_query_params(identifier, identifier_type)
      { identifier_type => identifier }
    end

    def build_cancel_body(options)
      {
        refund: options.fetch(:refund, true),
        restock: options.fetch(:restock, true),
        reason: options.fetch(:reason, 'OTHER'),
        staffNote: options.fetch(:staff_note, ''),
        storeId: options[:store_id]
      }.compact
    end

    def build_refund_body(refund_items, options)
      {
        refundLineItems: refund_items.map do |item|
          {
            lineItemId: item[:line_item_id],
            quantity: item[:quantity]
          }
        end,
        note: options.fetch(:note, ''),
        restock: options.fetch(:restock, true),
        storeId: options[:store_id]
      }.compact
    end

    def handle_response(response, action)
      case response.code
      when 200
        Rails.logger.info "ZProtect: Successfully #{action}"
        response.parsed_response
      when 400
        error_msg = "Invalid request parameters for #{action}"
        Rails.logger.error "ZProtect: #{error_msg} - #{response.body}"
        raise ArgumentError, error_msg
      when 401
        error_msg = "Authentication failed for #{action}"
        Rails.logger.error "ZProtect: #{error_msg}"
        raise SecurityError, error_msg
      when 404
        error_msg = "Resource not found for #{action}"
        Rails.logger.warn "ZProtect: #{error_msg}"
        { success: false, error: error_msg, orders: [] }
      when 422
        error_msg = "Business logic error for #{action}"
        Rails.logger.error "ZProtect: #{error_msg} - #{response.body}"
        raise StandardError, "#{error_msg}: #{response.parsed_response&.dig('error')}"
      when 429
        error_msg = "Rate limit exceeded for #{action}"
        Rails.logger.warn "ZProtect: #{error_msg}"
        raise StandardError, error_msg
      when 500..599
        error_msg = "ZProtect service error for #{action}"
        Rails.logger.error "ZProtect: #{error_msg} - #{response.code}"
        raise StandardError, "#{error_msg} (HTTP #{response.code})"
      else
        error_msg = "Unexpected response for #{action}"
        Rails.logger.error "ZProtect: #{error_msg} - #{response.code}"
        raise StandardError, "#{error_msg} (HTTP #{response.code})"
      end
    rescue HTTParty::Error, Net::TimeoutError => e
      error_msg = "Network error for #{action}: #{e.message}"
      Rails.logger.error "ZProtect: #{error_msg}"
      raise StandardError, error_msg
    end

    def validate_identifier!(identifier, identifier_type)
      raise ArgumentError, 'Identifier cannot be blank' if identifier.blank?
      raise ArgumentError, 'Identifier type must be email or phone' unless %w[email phone].include?(identifier_type)

      case identifier_type
      when 'email'
        raise ArgumentError, 'Invalid email format' unless identifier.match?(URI::MailTo::EMAIL_REGEXP)
      when 'phone'
        # Basic phone validation - at least 7 digits
        phone_digits = identifier.gsub(/\D/, '')
        raise ArgumentError, 'Phone number must have at least 7 digits' if phone_digits.length < 7
      end
    end

    def validate_order_id!(order_id)
      raise ArgumentError, 'Order ID cannot be blank' if order_id.blank?
    end

    def validate_refund_items!(refund_items)
      raise ArgumentError, 'Refund items cannot be empty' if refund_items.blank?

      refund_items.each do |item|
        raise ArgumentError, 'Line item ID is required' if item[:line_item_id].blank?
        raise ArgumentError, 'Quantity must be greater than 0' unless item[:quantity].to_i.positive?
      end
    end

    def mask_identifier(identifier, identifier_type)
      return identifier if Rails.env.development?

      case identifier_type
      when 'email'
        # Mask email: user@domain.com -> u***@d*****.com
        parts = identifier.split('@')
        return identifier if parts.length != 2

        username = parts[0]
        domain_parts = parts[1].split('.')

        masked_username = username.length > 1 ? "#{username[0]}***" : username
        masked_domain = domain_parts.map do |part|
          part.length > 1 ? "#{part[0]}#{'*' * (part.length - 1)}" : part
        end.join('.')

        "#{masked_username}@#{masked_domain}"
      when 'phone'
        # Mask phone: +1234567890 -> +***4567890 (show last 7 digits)
        return identifier if identifier.length <= 7

        visible_part = identifier[-7..]
        masked_part = '*' * (identifier.length - 7)
        "#{masked_part}#{visible_part}"
      else
        '***'
      end
    end
  end
end
