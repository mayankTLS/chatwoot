# ZProtect Integration Setup Guide

## Overview
This integration adds Shopify order management functionality to Chatwoot conversations, allowing agents to view, cancel, and refund orders directly from the conversation dashboard.

## Setup Steps

### 1. Environment Configuration
Add these variables to your `.env` file:

```bash
# ZProtect API Configuration
ZPROTECT_API_URL=https://zprotect.tlslogistics.org
ZPROTECT_API_KEY=KcVRDaQgpU6h8EK
```

### 2. Install Dependencies (if needed)
The integration uses HTTParty for API requests. If not already installed:

```bash
bundle install
```

### 3. Restart Chatwoot
After adding environment variables, restart your Chatwoot instance:

```bash
# If using Docker
docker-compose restart

# If using systemd
sudo systemctl restart chatwoot-web
sudo systemctl restart chatwoot-worker

# If using Procfile/development
overmind restart
```

### 4. Enable Feature Flag
The ZProtect integration is controlled by a feature flag. It's enabled by default, but you can verify:

1. Go to Super Admin (if applicable) or check `config/features.yml`
2. Ensure `zprotect_integration` is set to `enabled: true`

### 5. Test the Integration
1. Open a conversation with a contact that has an email or phone number
2. Look for "Order Management" section in the conversation sidebar
3. The section should show orders from the ZProtect API
4. Test cancel/refund functionality with appropriate orders

## Features

### Order Display
- **Multi-store support**: Shows orders from multiple Shopify stores
- **Order details**: Expandable view with line items, taxes, shipping
- **Status indicators**: Visual badges for financial and fulfillment status
- **Tracking information**: Links to carrier tracking pages

### Order Actions
- **Cancel orders**: Cancel with refund options and reason selection
- **Process refunds**: Select specific line items and quantities
- **Staff notes**: Add internal notes for both actions
- **Restock options**: Control inventory restocking

### Security Features
- **Server-side proxy**: All API calls go through Chatwoot backend
- **Authentication**: Uses Chatwoot's existing auth system
- **Authorization**: Only agents and admins can access order functions
- **PII masking**: Customer identifiers are masked in logs

## API Endpoints

The integration adds these endpoints to Chatwoot:

- `GET /api/v1/accounts/:account_id/integrations/zprotect/orders`
- `POST /api/v1/accounts/:account_id/integrations/zprotect/orders/:order_id/cancel`
- `POST /api/v1/accounts/:account_id/integrations/zprotect/orders/:order_id/refund`
- `GET /api/v1/accounts/:account_id/integrations/zprotect/health`

## Troubleshooting

### Orders Not Loading
1. Check environment variables are set correctly
2. Verify ZProtect API is accessible: `curl https://zprotect.tlslogistics.org/health`
3. Check Chatwoot logs for API errors
4. Ensure contact has email or phone number

### Feature Not Visible
1. Verify feature flag is enabled in `config/features.yml`
2. Check that `zprotect_integration` feature is enabled for the account
3. Ensure user has agent or admin role

### API Errors
1. Check ZProtect API key is valid
2. Verify network connectivity to zprotect.tlslogistics.org
3. Check Chatwoot logs for detailed error messages

## File Structure

### Backend Files
- `app/services/zprotect_service.rb` - API client service
- `app/controllers/api/v1/accounts/zprotect_controller.rb` - API endpoints
- `app/policies/zprotect_policy.rb` - Authorization rules
- `config/routes.rb` - Route definitions

### Frontend Files
- `app/javascript/dashboard/api/integrations/zprotect.js` - Frontend API client
- `app/javascript/dashboard/components/widgets/conversation/ZprotectOrdersList.vue` - Main component
- `app/javascript/dashboard/components/widgets/conversation/ZprotectOrderItem.vue` - Order display
- `app/javascript/dashboard/components/widgets/conversation/ZprotectCancelModal.vue` - Cancel workflow
- `app/javascript/dashboard/components/widgets/conversation/ZprotectRefundModal.vue` - Refund workflow

### Configuration Files
- `.env.example` - Environment variable template
- `config/features.yml` - Feature flag configuration
- `app/javascript/dashboard/composables/useUISettings.js` - Sidebar configuration
- `app/javascript/dashboard/i18n/locale/en/conversation.json` - Translations

## Usage

### For Agents
1. Open any conversation
2. Look for "Order Management" in the conversation sidebar
3. View customer orders (requires contact email/phone)
4. Use "Cancel Order" or "Process Refund" buttons as needed
5. Fill out the modal forms and submit

### For Administrators
- Feature can be disabled via feature flags
- Monitor usage through Chatwoot logs
- Configure environment variables for different ZProtect instances

## Security Considerations

- API key is stored server-side only
- All requests are authenticated through Chatwoot
- PII is automatically masked in logs
- User permissions are enforced through policies
- Feature can be disabled instantly via feature flags

## Support

For issues with this integration:
1. Check Chatwoot logs for errors
2. Verify ZProtect API connectivity
3. Test with curl commands to isolate issues
4. Check environment variable configuration