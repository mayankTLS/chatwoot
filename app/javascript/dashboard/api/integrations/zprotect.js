/* global axios */

import ApiClient from '../ApiClient';

class ZprotectAPI extends ApiClient {
  constructor() {
    super('integrations/zprotect', { accountScoped: true });
  }

  // Get orders by contact ID
  getOrders(contactId) {
    return axios.get(`${this.url}/orders`, {
      params: { contact_id: contactId },
    });
  }

  // Get orders by email or phone directly
  getOrdersByIdentifier(identifier, identifierType) {
    const params = {};
    params[identifierType] = identifier;

    return axios.get(`${this.url}/orders`, { params });
  }

  // Cancel an order
  cancelOrder(orderId, options = {}) {
    // URL encode the order ID to handle Shopify GID format (gid://shopify/Order/123)
    const encodedOrderId = encodeURIComponent(orderId);
    return axios
      .post(`${this.url}/orders/${encodedOrderId}/cancel`, {
        refund: options.refund !== false, // default true
        restock: options.restock !== false, // default true
        reason: options.reason || 'OTHER',
        staffNote: options.staffNote || '',
        storeId: options.storeId,
      })
      .catch(error => {
        // Enhanced error handling for multi-store operations
        if (error.response?.data?.error) {
          const errorMessage = error.response.data.error.toLowerCase();
          if (
            errorMessage.includes('store not found') ||
            errorMessage.includes('store_not_found')
          ) {
            error.response.data.error =
              'The store associated with this order could not be found. Please verify the store configuration.';
          } else if (
            errorMessage.includes('store unavailable') ||
            errorMessage.includes('store_unavailable')
          ) {
            error.response.data.error =
              'The store is temporarily unavailable. Please try again later.';
          } else if (errorMessage.includes('already cancelled')) {
            error.response.data.error =
              'This order has already been cancelled.';
          } else if (errorMessage.includes('cannot cancel fulfilled')) {
            error.response.data.error =
              'Cannot cancel an order that has already been fulfilled.';
          }
        }
        throw error;
      });
  }

  // Process refund for line items
  refundOrder(orderId, refundItems, options = {}) {
    // URL encode the order ID to handle Shopify GID format (gid://shopify/Order/123)
    const encodedOrderId = encodeURIComponent(orderId);
    return axios
      .post(`${this.url}/orders/${encodedOrderId}/refund`, {
        refundLineItems: refundItems.map(item => ({
          lineItemId: item.lineItemId,
          quantity: item.quantity,
        })),
        note: options.note || '',
        restock: options.restock !== false, // default true
        storeId: options.storeId,
      })
      .catch(error => {
        // Enhanced error handling for multi-store operations
        if (error.response?.data?.error) {
          const errorMessage = error.response.data.error.toLowerCase();
          if (
            errorMessage.includes('store not found') ||
            errorMessage.includes('store_not_found')
          ) {
            error.response.data.error =
              'The store associated with this order could not be found. Please verify the store configuration.';
          } else if (
            errorMessage.includes('store unavailable') ||
            errorMessage.includes('store_unavailable')
          ) {
            error.response.data.error =
              'The store is temporarily unavailable. Please try again later.';
          } else if (errorMessage.includes('already refunded')) {
            error.response.data.error =
              'One or more items have already been refunded.';
          } else if (errorMessage.includes('exceeds available')) {
            error.response.data.error =
              'The refund quantity exceeds the available quantity for one or more items.';
          } else if (errorMessage.includes('line item not found')) {
            error.response.data.error =
              'One or more line items could not be found in this order.';
          }
        }
        throw error;
      });
  }

  // Health check
  healthCheck() {
    return axios.get(`${this.url}/health`);
  }

  // Invalidate cache
  invalidateCache(identifier, identifierType) {
    const data = {};
    data[identifierType] = identifier;

    return axios.post(`${this.url}/orders/cache/invalidate`, data);
  }
}

export default new ZprotectAPI();
