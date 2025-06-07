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
    return axios.post(`${this.url}/orders/${orderId}/cancel`, {
      refund: options.refund !== false, // default true
      restock: options.restock !== false, // default true
      reason: options.reason || 'OTHER',
      staffNote: options.staffNote || '',
      storeId: options.storeId,
    });
  }

  // Process refund for line items
  refundOrder(orderId, refundItems, options = {}) {
    return axios.post(`${this.url}/orders/${orderId}/refund`, {
      refundLineItems: refundItems.map(item => ({
        lineItemId: item.lineItemId,
        quantity: item.quantity,
      })),
      note: options.note || '',
      restock: options.restock !== false, // default true
      storeId: options.storeId,
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
