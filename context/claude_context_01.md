# Claude Code Chat Context - PII Masking Analysis

## Initial Request
**User**: we have to mask email IDs and phone numbers for all agents in chatwoot. This means that they can not access the phone numbers or emails of any customers. However, this can not impact the functionality of the application in any way, shape or form. 
Additionally, we ll have to integrate with shopify to get the order history and order details of the suctomer accross several stores using a separate service. This service will take the phone number / email if the customer to surface relevant details form shopify. So the ability to do that must be there at all times. Of course, this will happen without the agent doing anything and the email id / phone number being passed to the service from the backend of chatwoot to the backend  of the service.
do not write any code. think hard, analyze the current codebase and schema and come up with 3 practical and robust approaches to achieve the above objectives. Focus on masking / hiding the email ids and phone numbers. you should have the context of the shopify bit but do not incorporate that into the plan for now. we will do that separately.
please ask any clarifying questions before proceeding. proceed to outline a plan only after you have full clarity, or i tell you that i can not provide more details in answer to your questions.

## Initial Analysis

### Contact Data Model and Usage Analysis

**Database Schema (`contacts` table):**
- `email`: string, nullable, with unique constraint per account (`uniq_email_per_account_contact`)
- `phone_number`: string, nullable, with unique constraint per account (`index_contacts_on_phone_number_and_account_id`)
- Both fields are stored as plain text with no encryption or masking at the database level

**Contact Model Validations:**
- Email: Validated using `Devise.email_regexp`, case-insensitive uniqueness per account
- Phone: Validated using regex `/\+[1-9]\d{1,14}\z/` (E.164 international format)
- Both fields allow blank values
- Email is automatically downcased before storage

**Key Methods:**
- `push_event_data()` and `webhook_data()` methods expose email and phone_number directly
- No data masking or redaction methods found

### API Endpoints Exposing Contact Data

**Main API Controller:** `/app/controllers/api/v1/accounts/contacts_controller.rb`

**Endpoints that expose email/phone:**
- `GET /api/v1/accounts/{account_id}/contacts` (index, search, filter, active)
- `GET /api/v1/accounts/{account_id}/contacts/{id}` (show)
- `POST /api/v1/accounts/{account_id}/contacts` (create)
- `PUT /api/v1/accounts/{account_id}/contacts/{id}` (update)

**JSON Serializers:**
- `/app/views/api/v1/models/_contact.json.jbuilder` - Exposes full email and phone_number
- `/app/views/public/api/v1/models/_contact.json.jbuilder` - Also exposes full email and phone_number

### Frontend Components Displaying Contact Information

**Key Contact Display Components:**
- `/app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue`
- `/app/javascript/dashboard/components-next/Contacts/ContactsCard/ContactsCard.vue`
- Various contact list, search, and detail components

### Role-Based Access Control and Permission Systems

**Permission System:**
- Uses Pundit policy gem for authorization
- Contact permissions in `/app/policies/contact_policy.rb`

**Contact-specific Permissions:**
- Most contact operations (view, update, create) are allowed for all authenticated users
- Only `import`, `export`, and `destroy` require administrator privileges
- No granular permissions for viewing email vs phone data

**Custom Roles (Enterprise):**
- Custom role system exists with `contact_manage` permission
- No field-level or data-type-specific permissions

## Clarifying Questions Asked

1. **Scope of Masking**: Should this apply to ALL agents, or should it be role-based where certain roles (like admins/supervisors) can still see the full data?

2. **Level of Masking**: What type of masking do you prefer?
   - Complete hiding (show nothing)
   - Partial masking (e.g., `jo***@example.com`, `+1***567890`)
   - Hashed/anonymized identifiers (e.g., `Contact_ABC123`)

3. **Functional Impact**: Should backend functions continue to work normally while only masking the *display* to agents?

4. **Configuration**: Should masking be:
   - Account-level setting (some Chatwoot accounts mask, others don't)?
   - Global system-wide setting?
   - Per-agent/role setting?

5. **Historical Data**: Should masking apply to new contacts only or all existing contacts?

6. **API Access**: Should the masking apply to only the web dashboard UI or all API responses?

## User Requirements Clarification

1. masking should apply to all agents. 
2. complete hiding
3. yes. all backend functions should continue to function normally and only display should be masked to agents.
4. please make it a per agent setting configurable only by the superadmin.
5. all new contacts and existing contacts. message history is exempt.
6. Masking should apply to only the web dashboard ui. nowhere else for now.

## User Model and Permissions Analysis

### User Model and Schema

**Key Fields for User Preferences:**
- `ui_settings` (JSONB) - Stores user interface preferences
- `custom_attributes` (JSONB) - Stores custom user attributes including phone number
- `message_signature` (TEXT) - User's message signature
- `display_name` (STRING) - Display name preference
- `availability` (ENUM) - Online status (deprecated, moved to AccountUser)

### AccountUser Model for Account-Specific Settings

**Key Fields:**
- `role` (ENUM) - agent (0), administrator (1)
- `availability` (ENUM) - online (0), offline (1), busy (2)
- `auto_offline` (BOOLEAN) - Auto-offline setting
- `custom_role_id` (BIGINT) - Reference to custom roles (enterprise feature)

### Super Admin Permissions

**Super Admin Model:**
- `SuperAdmin` extends `User` class (Single Table Inheritance)
- Super admins have access to all accounts and system-wide configuration
- Use Administrate gem for dashboard interface

### Existing Per-User Configuration Patterns

**A. UI Settings Pattern (Recommended for Masking Preference):**
- Stored in `users.ui_settings` (JSONB column)
- Managed via `useUISettings()` composable
- Updated through `/api/v1/profiles` endpoint

**B. Notification Settings Pattern:**
- Separate `NotificationSetting` model per account
- Uses flag-based system with bit operators

### User Serialization in API Responses

**Primary User Serialization:** `/app/views/api/v1/models/_user.json.jbuilder`
- Includes `ui_settings` - All UI preferences
- `custom_attributes` - Custom user data
- Account-specific data (role, permissions, availability)

## Frontend Data Flow Analysis

### Frontend Contact State Management

**Vuex Store Structure:**
- **Location**: `/app/javascript/dashboard/store/modules/contacts/`
- **State**: Stored in `contacts/index.js` with `records` object and `sortOrder` array
- **Actions**: Contact CRUD operations in `contacts/actions.js`
- **Getters**: Data transformation in `contacts/getters.js` using `camelcaseKeys`
- **Mutations**: State updates in `contacts/mutations.js`

**Key Data Transformation Points:**
```javascript
// In getters.js - Key transformation points for masking
getContactsList($state) {
  const contacts = $state.sortOrder.map(contactId => $state.records[contactId]);
  return camelcaseKeys(contacts, { deep: true }); // Transform here
},
getContactById: $state => id => {
  const contact = $state.records[id];
  return camelcaseKeys(contact || {}, {
    deep: true,
    stopPaths: ['custom_attributes'],
  }); // Transform here
}
```

### Contact API Service

**Location**: `/app/javascript/dashboard/api/contacts.js`
- Extends `ApiClient` with account-scoped endpoints
- **Key methods**: `get()`, `show()`, `search()`, `filter()`
- Data flows from API → Store Actions → Store State

### Contact Display Components

**Primary Components Displaying Contact PII:**

1. **ContactInfo.vue** - Lines 224-238: Email and phone display via `ContactInfoRow`
2. **ContactInfoRow.vue** - Line 62: `{{ value }}` renders the email/phone
3. **ContactsCard.vue** - Lines 114-122: Email and phone display in contact cards
4. **SearchResultContactItem.vue** - Lines 58-62: Search results showing email and phone

### User Authentication & UI Settings

**Auth State**: `/app/javascript/dashboard/store/modules/auth.js`
- `getUISettings($state)`: Returns `$state.currentUser.ui_settings || {}`
- `updateUISettings`: Action to update UI settings

**UI Settings Composable**: `/app/javascript/dashboard/composables/useUISettings.js`
- Provides reactive access to UI settings
- `updateUISettings()` function for updates

## Three Proposed Approaches

### Approach 1: Frontend Store-Level Masking (Recommended)

**Architecture**: Mask data at the Vuex store getter level before it reaches any display component.

**Implementation Strategy**:
- Add `mask_contact_pii: boolean` to User's `ui_settings` JSONB field
- Create a `ContactMaskingService` utility class
- Modify contact store getters (`getContactsList`, `getContactById`) to apply masking
- Super admin can toggle masking per agent via the Administrate dashboard

**Pros**:
- ✅ Centralized masking at single point (store getters)
- ✅ Automatic masking across all components displaying contact data
- ✅ Leverages existing UI settings infrastructure
- ✅ Clean separation - no component changes needed
- ✅ Easy to test and maintain

**Cons**:
- ❌ Slight performance impact on every contact data access
- ❌ Requires careful handling of camelCase/snake_case transformations

### Approach 2: Component-Level Masking with Composable

**Architecture**: Create a masking composable and apply it at each component that displays PII.

**Implementation Strategy**:
- Add `mask_contact_pii: boolean` to User's `ui_settings` 
- Create `useContactMasking()` composable 
- Modify each display component to use the composable
- Super admin controls via User settings in Administrate dashboard

**Pros**:
- ✅ Granular control at component level
- ✅ Easy to debug and trace masking behavior
- ✅ Minimal store performance impact
- ✅ Clear visibility of where masking is applied

**Cons**:
- ❌ Requires changes to multiple components
- ❌ Risk of missing components during implementation
- ❌ More maintenance burden
- ❌ Potential inconsistency across components

### Approach 3: API Response Transformation with User Context

**Architecture**: Apply masking at the API response level based on requesting user's preferences.

**Implementation Strategy**:
- Add `mask_contact_pii: boolean` to User's `ui_settings`
- Modify JSON serializers (`_contact.json.jbuilder`) to conditionally mask based on current user
- Use `current_user.ui_settings['mask_contact_pii']` in serializer logic
- Super admin controls via Administrate dashboard

**Pros**:
- ✅ Server-side masking - more secure
- ✅ No frontend performance impact
- ✅ Single point of control at API level
- ✅ Masked data never reaches frontend

**Cons**:
- ❌ More complex - requires user context in serializers
- ❌ Harder to implement conditional unmasking for specific actions
- ❌ Potential caching complications
- ❌ Less flexible for future UI-based masking controls

## User's Response to Approach Selection

**User**: sounds good. plan the implementation at 'function level change' detail. decide exactly what changes you whould do to what functions in which files. make sure all changes are in a feature flag that i can toggle at will. This has to be a regular, always available functionality of chatwoot and not a premium or gated feature. 
Do NOT MAKE CHANGES TO ANY FILES TILL I GIVE THE GO AHEAD.

in the end, think deeply and consider second and third order effects of the code changes you are proposing. let me know so that before starting the implementation, we have all details we need and all possible ways the changes can impact us.

## Feature Flag Analysis

### Feature Flag System in Chatwoot

Feature flags are defined in `/config/features.yml` with the following structure:
- `name`: Internal code name
- `display_name`: UI display name  
- `enabled`: Default state (true/false)
- `help_url`: Documentation link (optional)
- `premium`: Whether it's a premium feature (optional)
- `deprecated`: Whether to hide from UI (optional)

### Feature Flag Implementation Pattern

Feature flags use the `Featurable` concern:
- Uses FlagShihTzu gem for bit-based flags
- Stored in `feature_flags` column on Account model
- Accessed via `account.feature_enabled?('feature_name')`
- Example usage: `account.feature_enabled?('ip_lookup')`

## Complete Implementation Plan with Risk Mitigation

### 1. Add Feature Flag
**File**: `/config/features.yml` (Add at line 172)
```yaml
- name: contact_pii_masking
  display_name: Contact PII Masking
  enabled: false
```

### 2. Update User Dashboard for Super Admin Control
**File**: `/app/dashboards/user_dashboard.rb`

**Function**: `ATTRIBUTE_TYPES` constant (line 10)
```ruby
ui_settings: SerializedField.with_options(
  types: {
    mask_contact_pii: :boolean
  }
)
```

**Function**: `FORM_ATTRIBUTES` array (line 77)
```ruby
FORM_ATTRIBUTES = %i[
  name
  avatar
  display_name
  email
  password
  confirmed_at
  type
  ui_settings
].freeze
```

### 3. Create Custom Administrate Field
**File**: `/app/fields/ui_settings_field.rb` (NEW FILE)
```ruby
require 'administrate/field/base'

class UiSettingsField < Administrate::Field::Base
  def to_s
    data&.dig('mask_contact_pii') ? 'PII Masking: Enabled' : 'PII Masking: Disabled'
  end
end
```

### 4. Add Server-Side Validation & Audit Trail
**File**: `/app/controllers/api/v1/profiles_controller.rb`

Enhanced `update` method with validation and audit logging for PII masking changes.

### 5. Add CSP Headers for Console Protection
**File**: `/config/initializers/content_security_policy.rb` (NEW FILE)

Content Security Policy to prevent console access in production.

### 6. Add Feature Flag Validation Service
**File**: `/app/services/pii_masking_validation_service.rb` (NEW FILE)

Service to validate masking requests with fail-secure behavior.

### 7. Enhanced Contact Masking Service with Security
**File**: `/app/javascript/dashboard/services/ContactMaskingService.js` (NEW FILE)

Client-side service for contact data masking with validation and alternative identifiers.

### 8. Enhanced Contact Store Getters with Validation
**File**: `/app/javascript/dashboard/store/modules/contacts/getters.js`

Modified `getContactsList` and `getContactById` functions with centralized masking logic.

### 9. Enhanced UI Settings Composable with Permissions
**File**: `/app/javascript/dashboard/composables/useUISettings.js`

Extended composable with PII masking methods and permission checks.

### 10. Add Contact Alternative Identifier Display
**File**: `/app/javascript/dashboard/components/ContactIdentifier.vue` (NEW FILE)

Component to display masked identifiers instead of PII.

## Critical Analysis Request

**User**: will these changes break any existing functionality of chatwoot?

## Breaking Changes Analysis

### CRITICAL BREAKING CHANGES (System Failure)

#### 1. **Email Channel Communication - COMPLETELY BROKEN**
- **Impact**: Email conversations cannot function
- **Reason**: Contact email becomes "[MASKED]", breaking email routing and reply threading
- **Affected Files**: 
  - `/app/mailboxes/mailbox_helper.rb` lines 107-120
  - `/app/builders/contact_inbox_builder.rb` lines 31-47
  - `/app/finders/email_channel_finder.rb`

#### 2. **SMS/WhatsApp Communication - COMPLETELY BROKEN** 
- **Impact**: SMS and WhatsApp messaging fails
- **Reason**: Phone numbers become "[MASKED]", preventing message delivery
- **Affected Files**:
  - `/app/services/sms/incoming_message_service.rb`
  - `/app/services/twilio/incoming_message_service.rb`
  - All SMS/WhatsApp services

#### 3. **Contact Deduplication - COMPLETELY BROKEN**
- **Impact**: System creates duplicate contacts instead of merging
- **Reason**: Contact matching logic fails when email/phone = "[MASKED]"
- **Affected Files**: 
  - `/app/actions/contact_identify_action.rb` lines 35-42, 62, 68, 92
  - `/app/services/data_import/contact_manager.rb` lines 35-44

#### 4. **Database Constraints - VIOLATION ERRORS**
- **Impact**: Multiple contacts cannot be created with "[MASKED]" values
- **Reason**: Unique constraints on email/phone per account
- **Database Schema**: Lines 35-36 in contact model

### MAJOR BREAKING CHANGES (Feature Loss)

#### 5. **Contact Search/Filtering - NON-FUNCTIONAL**
- **Impact**: Users cannot search contacts by email/phone
- **Reason**: Search queries only find "[MASKED]" literal strings
- **Affected**: `/app/services/search_service.rb` lines 30-31, 88-91

#### 6. **Third-Party Integrations - DATA CORRUPTION**
- **Impact**: CRM sync, webhook data becomes meaningless
- **Reason**: External systems receive "[MASKED]" instead of real data
- **Affected Files**:
  - `/app/models/contact.rb` lines 162-176 (`webhook_data` method)
  - `/app/listeners/webhook_listener.rb` lines 54-67

#### 7. **Contact Import/Export - DATA LOSS**
- **Impact**: Contact data exports become unusable
- **Reason**: Exported data contains "[MASKED]" instead of real values
- **Affected**: `/app/jobs/account/contacts_export_job.rb`

#### 8. **Automation Rules - LOGIC FAILURE**
- **Impact**: Automations based on email/phone patterns stop working
- **Reason**: Rules cannot match against "[MASKED]" strings
- **Affected**: `/app/services/automation_rules/conditions_filter_service.rb` lines 130-141

### MODERATE BREAKING CHANGES (Degraded Experience)

#### 9. **Campaign Delivery - MESSAGING FAILURE**
- **Impact**: SMS campaigns cannot be sent
- **Reason**: "[MASKED]" is not a valid phone number
- **Affected**: `/app/services/sms/oneoff_sms_campaign_service.rb` lines 23-25

#### 10. **Contact Validation - FORM ERRORS**
- **Impact**: Contact creation/update forms may fail validation
- **Reason**: "[MASKED]" doesn't match email/phone regex patterns
- **Affected**: Contact model validations lines 48-53

### Complete Contact-Dependent Workflow Analysis

#### Webhook Payloads with Contact Email/Phone Data
**High Impact** - Contact email and phone numbers are extensively exposed in webhooks:
- Contact creation/update events send complete contact data to external webhooks
- Critical for third-party integrations - External systems receive real contact data for CRM sync

#### Conversation Creation Logic Dependent on Contact Identification
**Critical Functionality** - Contact identification is fundamental to conversation routing:
- Email channels require `contact.email`
- SMS/WhatsApp channels require `contact.phone_number`
- Contact deduplication relies on email/phone uniqueness

#### Message Routing Logic Based on Contact Email/Phone
**Channel-Specific Critical Logic**:
- Email routing uses sender email to create/find contacts
- SMS/WhatsApp uses phone numbers for contact lookup and message routing

#### Notification Systems Using Contact Email/Phone
- Email notifications use contact email for reply-to functionality
- Reply emails use contact email for direct responses

#### Customer Communication Flows Needing Real Contact Data
- SMS Campaigns require `contact.phone_number` for campaign delivery
- WhatsApp/SMS Outbound uses contact phone numbers from contact_inbox.source_id
- Email Replies use contact email addresses for conversation threading

#### Third-Party API Integrations Sending Contact Data
- Clearbit Lookup uses contact email for enrichment lookups
- CRM Integrations sync contact data to external CRMs
- Webhook integrations expose full contact data to external systems

#### Channel-Specific Logic Depending on Contact Data
- WhatsApp: Phone number validation and messaging
- Email: Email address routing and validation
- Contact-Inbox Source ID Generation: Phone numbers and emails become source_id for different channels

## ROOT CAUSE ANALYSIS

The fundamental issue is that **Chatwoot treats contact email/phone as functional identifiers, not just display data**. These fields are used for:

1. **Channel Routing**: Determining which inbox handles communications
2. **Contact Identity**: Uniquely identifying and merging contacts  
3. **Communication**: Actual delivery addresses for outbound messages
4. **Integration**: Data exchange with external systems
5. **Business Logic**: Validation, automation, and workflow rules

## ALTERNATIVE SOLUTIONS THAT WON'T BREAK FUNCTIONALITY

### **Approach A: Role-Based Display Masking (Recommended)**
- Mask data only in UI components for specific user roles
- Keep real data in store/backend for all business logic
- Components check user permissions before displaying email/phone

### **Approach B: Separate Display Layer**
- Create masked display versions alongside real data
- Use `contact.display_email` and `contact.display_phone` in UI
- Keep `contact.email` and `contact.phone_number` for business logic

### **Approach C: API Response Filtering** 
- Modify JSON serializers to mask data based on requesting user's role
- Frontend never receives real data for masked users
- Preserve all backend functionality

### **Approach D: Database-Level Column Encryption**
- Encrypt PII at database level with application-level decryption
- Transparent to application logic
- Role-based decryption keys

## SAFE IMPLEMENTATION PLAN (ALTERNATIVE)

### **Phase 1: Add Parallel Display Fields**
```javascript
// In contact store getters
const displayContact = {
  ...contact,
  display_email: shouldMask ? '[MASKED]' : contact.email,
  display_phone: shouldMask ? '[MASKED]' : contact.phone_number,
  // Keep original fields for business logic
  email: contact.email,
  phone_number: contact.phone_number
};
```

### **Phase 2: Update UI Components**
```vue
<!-- Use display versions in templates -->
<template>
  <span>{{ contact.display_email || contact.email }}</span>
  <span>{{ contact.display_phone || contact.phone_number }}</span>
</template>
```

### **Phase 3: Preserve Business Logic**
```javascript
// Business logic continues using real fields
if (contact.email) {
  // Email validation, routing, automation - all works
}
```

## FINAL RECOMMENDATION

**DO NOT implement the proposed PII masking approach** as it will break core Chatwoot functionality. Instead:

1. **Use role-based display masking** that preserves real data for business logic
2. **Implement at the component level** rather than store getter level  
3. **Create parallel display fields** instead of replacing actual data
4. **Test extensively** with all communication channels and integrations

The current proposal would require a complete rewrite of Chatwoot's contact-based systems, making it unsuitable for production use.

## User's Request for Context Dump

**User**: dump the entire chat in the claude_context_01.md file