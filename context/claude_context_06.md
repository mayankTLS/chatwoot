# ZProtect Integration Analysis and Implementation Plan

## Context
This document contains the analysis and planning for integrating ZProtect API functionality into Chatwoot's conversation dashboard, specifically to add Shopify order management capabilities (view, cancel, refund) in the contact details section during conversations.

## User Requirements
- Integration of ZProtect API server-side endpoints into Chatwoot
- Port ZProtect Zendesk app functionality to Chatwoot conversations dashboard
- Expected outcome: When a conversation is opened, display customer orders (identified by email/phone) in details section with cancel/refund functionality
- Must not break existing Chatwoot functionality
- Server-side integration preferred for PII security

## Key Findings

### ZProtect API Analysis
The ZProtect API (hosted at zprotect.tlslogistics.org) provides:

**Core Endpoints:**
- `GET /orders` - Fetch customer orders by email or phone
- `POST /orders/:orderId/cancel` - Cancel order with refund options
- `POST /orders/:orderId/refund` - Process partial/full refunds
- `POST /webhook/ticket-created` - Handle Zendesk webhooks
- `GET /health` - Health check

**Multi-Store Support:**
- Supports multiple Shopify stores in single API
- Store-specific configuration and authentication
- Consolidated response formatting
- Performance optimization with caching

**Authentication:**
- API key-based with `x-auth-key` header
- Rate limiting: 100 requests per 15-minute window
- Request size limit: 1MB

**Example Working Request:**
```bash
curl --location 'https://zprotect.tlslogistics.org/orders?phone=919899921918' \
--header 'x-auth-key: KcVRDaQgpU6h8EK'
```

### ZProtect Zendesk App Analysis
**Architecture:**
- VIPER pattern (View, Interactor, Presenter, Entity, Router)
- Clean separation of concerns for maintainability
- Modal workflows for complex actions (cancel/refund)

**UI Features:**
- Multi-store expandable sections
- Store status indicators (✅ success, ⚠️ errors)
- Order list with expandable details
- Cancel order workflow with options (refund, restock, reason, notes)
- Refund workflow with line item selection and quantity inputs
- Real-time feedback and error handling

### Chatwoot Analysis
**Critical Discovery:** Chatwoot already has Shopify integration, but it's **restricted for self-hosted installations**:

```yaml
# config/features.yml
- name: shopify_integration
  display_name: Shopify Integration
  enabled: false
  chatwoot_internal: true  # ← Restricted to Chatwoot SaaS
```

**Existing Architecture:**
- Vue.js frontend with Composition API + Tailwind CSS
- Ruby on Rails backend
- Contact details with custom attributes support
- Conversation sidebar with accordion sections
- Integration hook system for external services

**Key Integration Points:**
- Contact model: `additional_attributes` (JSONB) for custom data
- Conversation sidebar: `ContactPanel.vue` with accordion sections
- Custom attributes system for extensible contact data
- API patterns: `app/controllers/api/v1/accounts/`

## Implementation Approach

### Strategy: Lightweight Proxy Integration (Minimal Overhead)
Since Chatwoot's existing Shopify integration is restricted, build a standalone integration that:
1. Proxies ZProtect API through Chatwoot backend for security
2. Ports Zendesk app UI components to Vue.js
3. Integrates with existing conversation sidebar
4. No database schema changes needed

### Environment Configuration
```bash
# .env
ZPROTECT_API_URL=https://zprotect.tlslogistics.org
ZPROTECT_API_KEY=KcVRDaQgpU6h8EK
```

## Comprehensive Implementation Plan

### Backend Implementation

**1. Service Layer**
- **File**: `app/services/zprotect_service.rb`
- HTTP client using Net::HTTP or HTTParty
- Methods: `get_orders(phone/email)`, `cancel_order()`, `refund_order()`
- Error handling and PII masking

**2. API Controller**
- **File**: `app/controllers/api/v1/accounts/zprotect_controller.rb`
- Routes: GET /orders, POST /orders/:id/cancel, POST /orders/:id/refund
- Input validation and authentication
- Proxy to ZProtect API with proper headers

**3. Routes Configuration**
- **File**: `config/routes.rb`
- Add ZProtect routes to existing API v1 accounts namespace

**4. Authorization**
- **File**: `app/policies/zprotect_policy.rb`
- Ensure agents can only access orders for assigned conversations

### Frontend Implementation

**5. API Client**
- **File**: `app/javascript/dashboard/api/zprotect.js`
- Axios-based client matching backend endpoints

**6. Main Orders Component**
- **File**: `app/javascript/dashboard/components/widgets/conversation/ZprotectOrdersList.vue`
- Port from Zendesk `orderView.js`
- Multi-store sections, loading states, error handling

**7. Order Item Component**
- **File**: `app/javascript/dashboard/components/widgets/conversation/ZprotectOrderItem.vue`
- Individual order display with status badges and action buttons

**8. Cancel Order Modal**
- **File**: `app/javascript/dashboard/components/widgets/conversation/ZprotectCancelModal.vue`
- Order confirmation, refund options, reason selection, staff notes

**9. Refund Order Modal**
- **File**: `app/javascript/dashboard/components/widgets/conversation/ZprotectRefundModal.vue`
- Line item selection, quantity inputs, restock options

**10. Integration Points**
- **File**: `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue`
- Add ZprotectOrdersList to existing accordion sections

### Configuration & Localization

**11. Feature Flag**
- **File**: `config/features.yml`
- Add `zprotect_integration` feature flag

**12. Translations**
- **File**: `config/locales/en.yml`
- Add ZProtect-specific UI strings

## Implementation Phases

### Phase 1: Core Backend (1-2 days)
1. Environment configuration
2. ZprotectService implementation
3. Controller and routes
4. Basic error handling

### Phase 2: Core Frontend (2-3 days)
1. API client
2. Main orders list component
3. Order item component
4. Integration with conversation sidebar

### Phase 3: Action Modals (2-3 days)
1. Cancel order modal
2. Refund order modal
3. Form validation and error handling

### Phase 4: Enhanced Features (1-2 days)
1. Order details modal
2. Contact details integration
3. UI polish and testing

### Phase 5: Production Readiness (1 day)
1. Security review
2. Performance optimization
3. Documentation

## Key Benefits

1. **Minimal Backend Changes**: Only 3-4 new files
2. **Reuses Existing Patterns**: Follows Chatwoot's architecture
3. **Server-side Security**: All API calls proxied through Chatwoot
4. **UI Consistency**: Uses Chatwoot's design system
5. **No Breaking Changes**: Completely additive
6. **Feature Flag Control**: Can enable/disable easily

## Security Considerations

- API key stored in environment variables
- Server-side proxy prevents client-side API exposure
- PII masking in logs consistent with Chatwoot patterns
- Input validation for phone/email formats
- Authorization checks for conversation access

## Technical Notes

- ZProtect API is HTTPS-based and production-ready
- Multi-store support allows handling customers across multiple Shopify stores
- Existing Zendesk app provides proven UI patterns and workflows
- Vue.js Composition API integration follows Chatwoot's current architecture
- No licensing conflicts as this is completely independent of Chatwoot's restricted Shopify integration

## Next Steps

1. Confirm environment setup and API connectivity
2. Implement Phase 1 backend proxy
3. Validate data flow and API responses
4. Port UI components from Zendesk JavaScript to Vue.js
5. Integration testing for end-to-end functionality