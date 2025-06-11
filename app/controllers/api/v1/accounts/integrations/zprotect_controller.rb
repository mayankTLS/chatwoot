class Api::V1::Accounts::Integrations::ZprotectController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :validate_zprotect_config
  before_action :set_contact, only: [:orders]
  before_action :set_order_params, only: [:cancel_order, :refund_order]

  def orders
    identifier, identifier_type = extract_contact_identifier

    if identifier.blank?
      render json: {
        success: false,
        error: 'Contact must have email or phone number',
        orders: []
      }, status: :unprocessable_entity
      return
    end

    # Prevent browser caching of order data
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = '0'

    begin
      result = ZprotectService.get_customer_orders(
        identifier: identifier,
        identifier_type: identifier_type,
        user_id: current_user.id
      )

      render json: result
    rescue ArgumentError => e
      render json: {
        success: false,
        error: "Invalid request: #{e.message}",
        orders: []
      }, status: :bad_request
    rescue SecurityError
      render json: {
        success: false,
        error: 'Authentication failed with ZProtect service',
        orders: []
      }, status: :unauthorized
    rescue StandardError => e
      Rails.logger.error "ZProtect orders error: #{e.message}"
      render json: {
        success: false,
        error: 'Failed to fetch orders. Please try again.',
        orders: []
      }, status: :service_unavailable
    end
  end

  def cancel_order
    Rails.logger.info "ZProtect cancel_order called with order_id: #{@order_id}, params: #{params.except(:controller, :action, :account_id, :format)}"

    options = {
      refund: params[:refund] != false, # default true
      restock: params[:restock] != false, # default true
      reason: params[:reason] || 'OTHER',
      staff_note: params[:staffNote] || params[:staff_note] || '',
      store_id: params[:storeId] || params[:store_id]
    }

    result = ZprotectService.cancel_order(
      order_id: @order_id,
      options: options,
      user_id: current_user.id
    )

    render json: result
  rescue ArgumentError => e
    render json: {
      success: false,
      error: "Invalid request: #{e.message}"
    }, status: :bad_request
  rescue SecurityError
    render json: {
      success: false,
      error: 'Authentication failed with ZProtect service'
    }, status: :unauthorized
  rescue StandardError => e
    Rails.logger.error "ZProtect cancel order error: #{e.message}"
    render json: {
      success: false,
      error: "Failed to cancel order: #{e.message}"
    }, status: :service_unavailable
  end

  def refund_order
    Rails.logger.info "ZProtect refund_order called with order_id: #{@order_id}, params: #{params.except(:controller, :action, :account_id, :format)}"

    refund_items = parse_refund_items
    options = {
      note: params[:note] || '',
      restock: params[:restock] != false, # default true
      store_id: params[:storeId] || params[:store_id]
    }

    result = ZprotectService.refund_order(
      order_id: @order_id,
      refund_items: refund_items,
      options: options,
      user_id: current_user.id
    )

    render json: result
  rescue ArgumentError => e
    render json: {
      success: false,
      error: "Invalid request: #{e.message}"
    }, status: :bad_request
  rescue SecurityError
    render json: {
      success: false,
      error: 'Authentication failed with ZProtect service'
    }, status: :unauthorized
  rescue StandardError => e
    Rails.logger.error "ZProtect refund order error: #{e.message}"
    render json: {
      success: false,
      error: "Failed to process refund: #{e.message}"
    }, status: :service_unavailable
  end

  def health
    result = ZprotectService.health_check
    render json: result
  rescue StandardError => e
    Rails.logger.error "ZProtect health check error: #{e.message}"
    render json: {
      success: false,
      error: 'ZProtect service unavailable'
    }, status: :service_unavailable
  end

  def invalidate_cache
    identifier = params[:email] || params[:phone]
    identifier_type = params[:email] ? 'email' : 'phone'

    if identifier.blank?
      render json: {
        success: false,
        error: 'Email or phone number is required'
      }, status: :bad_request
      return
    end

    begin
      result = ZprotectService.invalidate_cache(
        identifier: identifier,
        identifier_type: identifier_type,
        user_id: current_user.id
      )

      render json: result
    rescue ArgumentError => e
      render json: {
        success: false,
        error: "Invalid request: #{e.message}"
      }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "ZProtect cache invalidation error: #{e.message}"
      render json: {
        success: false,
        error: 'Failed to invalidate cache'
      }, status: :service_unavailable
    end
  end

  private

  def check_authorization
    authorize(:zprotect, :access?)
  end

  def validate_zprotect_config
    url = ENV.fetch('ZPROTECT_API_URL', nil)
    key = ENV.fetch('ZPROTECT_API_KEY', nil)
    return unless url.blank? || key.blank?

    render json: { success: false, error: 'ZProtect service not configured' }, status: :service_unavailable
  end

  def set_contact
    contact_id = params[:contact_id] || params[:contactId]

    return if contact_id.blank?

    @contact = current_account.contacts.find_by(id: contact_id)

    return if @contact

    render json: {
      success: false,
      error: 'Contact not found',
      orders: []
    }, status: :not_found
  end

  def set_order_params
    # Get order ID from params and decode it to handle URL-encoded Shopify GIDs
    raw_order_id = params[:order_id] || params[:orderId] || params[:id]
    @order_id = raw_order_id.present? ? CGI.unescape(raw_order_id) : nil

    Rails.logger.debug { "ZProtect order operation - Raw order ID: #{raw_order_id}, Decoded: #{@order_id}" }

    return if @order_id.present?

    render json: {
      success: false,
      error: 'Order ID is required'
    }, status: :bad_request
  end

  def extract_contact_identifier
    # If contact_id provided, get identifier from contact
    if @contact
      if @contact.email.present?
        return [@contact.email, 'email']
      elsif @contact.phone_number.present?
        return [@contact.phone_number, 'phone']
      else
        return [nil, nil]
      end
    end

    # Otherwise, check for direct identifier params
    if params[:email].present?
      [params[:email], 'email']
    elsif params[:phone].present?
      [params[:phone], 'phone']
    else
      [nil, nil]
    end
  end

  def parse_refund_items
    refund_items = params[:refundLineItems] || params[:refund_line_items] || []

    raise ArgumentError, 'At least one line item must be specified for refund' if refund_items.blank?

    refund_items.map do |item|
      {
        line_item_id: item[:lineItemId] || item[:line_item_id],
        quantity: item[:quantity].to_i
      }
    end
  end
end
