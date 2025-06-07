> This session is being continued from a previous conversation that ran out of context. The conversation is summarized below:
  Analysis:
  Let me chronologically analyze this conversation about implementing PII masking in Chatwoot:

  1. **Initial User Request**: User wants to mask email IDs and phone numbers for all agents in Chatwoot, while preserving all application
  functionality and maintaining backend access for Shopify integration.

  2. **My Initial Analysis**: I analyzed the Chatwoot codebase extensively, examining contact data models, API endpoints, frontend components, and
  permission systems. I identified that contacts store email/phone as plain text with no existing masking.

  3. **Clarifying Questions**: I asked 6 specific questions about scope, masking level, functional impact, configuration, historical data, and API
  access.

  4. **User Requirements Clarification**: User specified: all agents, complete hiding, backend functions continue normally, per-agent setting by super
  admin only, all contacts affected, web dashboard UI only.

  5. **Three Initial Approaches**: I proposed three approaches - frontend store-level masking (recommended), component-level masking, and API response
  transformation.

  6. **User Acceptance and Implementation Request**: User accepted approach 1 and requested detailed function-level implementation with feature flags.

  7. **Detailed Implementation Plan**: I created a comprehensive plan with backend changes, frontend changes, and risk mitigation measures.

  8. **Critical Breaking Changes Discovery**: Upon deeper analysis, I discovered the proposed approach would completely break core Chatwoot
  functionality including email routing, SMS delivery, contact deduplication, and webhook integrations.

  9. **User Question About Breaking Changes**: User asked if changes would break existing functionality.

  10. **My Critical Analysis**: I provided extensive analysis showing the approach would break 10+ critical systems and recommended against it.

  11. **Alternative Recommendation**: I recommended role-based display masking with parallel display fields instead.

  12. **User Acceptance of Alternative**: User confirmed acceptance of the safer alternative approach.

  13. **Safe Implementation Plan**: I provided detailed function-level implementation for the safe approach that preserves all functionality while
  achieving masking goals.

  Key technical concepts include Vuex store patterns, feature flags, UI settings, parallel display fields, and component-level masking.

  The conversation shows a critical pivot from a dangerous implementation to a safe one based on thorough analysis.

  Summary:
  1. Primary Request and Intent:
     - Implement email and phone number masking for all agents in Chatwoot to hide customer PII from agents in the UI
     - Ensure no impact on application functionality, particularly preserving backend access for Shopify integration
     - Make it a per-agent setting configurable only by super admins
     - Apply to all existing and new contacts (message history exempt)
     - Mask only in web dashboard UI, not APIs or backend systems
     - Implement with feature flag control as regular (non-premium) functionality

  2. Key Technical Concepts:
     - Chatwoot's Vuex store architecture and contact data flow
     - Feature flag system using FlagShihTzu and YAML configuration
     - UI settings stored in JSONB fields on User model
     - Administrate gem for super admin dashboard
     - Contact deduplication and identification systems
     - Channel routing (email, SMS, WhatsApp) dependencies on contact data
     - Webhook integrations and external system dependencies
     - Role-based display masking vs data replacement
     - Parallel display fields architecture
     - Component-level masking implementation

  3. Files and Code Sections:
     - `/config/features.yml` - Feature flag definition for contact_pii_masking
     - `/app/dashboards/user_dashboard.rb` - Super admin control interface
       - Added ui_settings field to ATTRIBUTE_TYPES and FORM_ATTRIBUTES
     - `/app/controllers/api/v1/profiles_controller.rb` - Server-side validation and audit trail
       - Enhanced update method with PII masking permission checks and logging
     - `/app/javascript/dashboard/services/ContactDisplayService.js` - NEW FILE
       - Core service for creating display-safe contact data with parallel fields
       ```javascript
       static createDisplayContact(contact, shouldMask = false) {
         const displayContact = { ...contact };
         if (shouldMask) {
           displayContact.displayEmail = this.maskEmail(contact.email);
           displayContact.displayPhone = this.maskPhone(contact.phoneNumber);
           // Preserve original fields for business logic
         }
         return displayContact;
       }
       ```
     - `/app/javascript/dashboard/store/modules/contacts/getters.js` - Safe store getter modifications
       - Modified getContactsList and getContactById to use ContactDisplayService
     - `/app/javascript/dashboard/composables/useContactDisplay.js` - NEW FILE
       - Composable for managing contact PII display with utility functions
     - Component updates: ContactInfo.vue, ContactsCard.vue, SearchResultContactItem.vue
       - Updated to use getDisplayEmail(), getDisplayPhone(), getContactIdentifier()

  4. Errors and fixes:
     - **Critical Architecture Error**: Initially proposed replacing contact email/phone with "[MASKED]" strings in store getters
       - **Fix**: Changed to parallel display fields approach that preserves original data
       - **User Feedback**: User asked "will these changes break any existing functionality?" leading to discovery of breaking changes
     - **Breaking Changes Discovery**: Found that masking real data would break email routing, SMS delivery, contact deduplication, webhooks,
  automation rules, and 10+ other core systems
       - **Fix**: Redesigned to use display-only masking with preserved backend functionality

  5. Problem Solving:
     - Solved contact data flow analysis by examining Vuex store patterns and component hierarchies
     - Solved permission system requirements by leveraging existing UI settings infrastructure
     - Solved functionality preservation by designing parallel display field architecture
     - Solved super admin control by extending Administrate dashboard
     - Critical pivot from dangerous data replacement to safe display masking approach

  6. All user messages:
     - Initial request for PII masking with Shopify integration context
     - Clarification responses: all agents, complete hiding, backend preservation, per-agent by super admin, all contacts, UI only
     - "sounds good. plan the implementation at 'function level change' detail..."
     - "will these changes break any existing functionality of chatwoot?"
     - "ok... lets get back to the feature discussion. Your current recommendation is to not go ahead with the proposed plan, but to: 1. Use role-based
   display masking... correct?"
     - "yes" (confirming acceptance of alternative approach)

  7. Pending Tasks:
     - No explicitly pending tasks - user confirmed acceptance of safe implementation plan

  8. Current Work:
     Immediately before this summary request, I was completing the comprehensive safe implementation plan including:
     - Detailed function-level changes for backend (feature flags, super admin controls, validation)
     - Frontend services (ContactDisplayService, useContactDisplay composable)
     - Component updates for all contact display areas
     - Comprehensive testing strategy with unit tests, integration tests, and deployment phases
     - The plan preserves all Chatwoot functionality while achieving PII masking goals through parallel display fields

  9. Optional Next Step:
     Based on the user's confirmation "yes" to proceed with the safe implementation approach, the next step would be to begin implementation starting
  with Phase 1 (Backend Foundation) as outlined in the plan. However, since this was a comprehensive planning exercise and the user has not explicitly
  requested to begin implementation, I should await user confirmation before proceeding with actual code changes..
  ⎿  Read claude_context_01.md (553 lines)
  ⎿  Read app/helpers/billing_helper.rb (26 lines)
  ⎿  Read app/models/channel/email.rb (74 lines)
  ⎿  Read app/models/channel/whatsapp.rb (71 lines)
  ⎿  Read app/services/sms/oneoff_sms_campaign_service.rb (33 lines)
  ⎿  Todo list read (4 items)

> /compact

> think deeply and consider second and third order effects of the code changes you are now proposing. let me know so that before starting the
    implementation, we have all details we need and all possible ways the changes can impact us.

✻ Thinking…

  The user is asking me to analyze the comprehensive safe implementation plan I provided in the conversation for potential second and third-order
  effects. Based on the conversation summary, I had previously identified that the original approach would break critical Chatwoot functionality, and
  then proposed a safer alternative using role-based display masking with parallel display fields.

  Let me analyze the safe implementation plan and think through potential effects:

  The Safe Implementation Plan Analysis

  From the context, the safe plan involves:
  1. Adding parallel display fields (display_email, display_phone)
  2. Using role-based masking at the component level
  3. Preserving original email/phone data for business logic
  4. Feature flag control
  5. Super admin configuration

  Let me think through potential effects systematically:

  First-Order Effects (Direct Impact)

  - UI displays masked data for agents
  - Business logic continues using real data
  - Super admin can configure per-agent

  Second-Order Effects (Indirect Impact)

  - Performance implications from additional data processing
  - Component testing complexity increases
  - User experience changes for agents
  - Data consistency challenges

  Third-Order Effects (Cascading Impact)

  - Training and documentation needs
  - Support complexity
  - Future feature development considerations
  - Potential security implications

  Let me analyze each area systematically based on the codebase I've examined.

● Comprehensive Risk Analysis: Second and Third-Order Effects

  Based on the safe implementation plan (role-based display masking with parallel fields), here's my deep analysis of potential impacts:

  🔴 HIGH-IMPACT CONCERNS

  1. Component State Management Complexity

  Second-Order Effect: Components now need to handle dual email/phone states
  // Components must differentiate between:
  contact.email              // For business logic
  contact.display_email      // For UI display
  contact.phone_number       // For business logic
  contact.display_phone      // For UI display

  Third-Order Effect: Future developers may accidentally use display fields in business logic, causing subtle bugs

  Mitigation Required: Strong naming conventions and comprehensive documentation

  2. Search and Filter Functionality Degradation

  Second-Order Effect: Agent search capabilities become limited
  - Agents can't search by partial email/phone if they can't see the data
  - Search suggestions won't work for masked fields
  - Auto-completion features break for masked agents

  Third-Order Effect: Agent productivity decreases, leading to longer resolution times

  3. Data Export and Reporting Inconsistencies

  Second-Order Effect: Reports may show inconsistent data
  - Contact exports might include masked data
  - Analytics lose granularity for masked users
  - CSV exports become less useful for agents

  Third-Order Effect: Business intelligence and reporting accuracy degrades

  🟡 MEDIUM-IMPACT CONCERNS

  4. Performance Implications at Scale

  Second-Order Effect: Additional processing overhead
  // Every contact access now requires masking calculation
  const shouldMask = getUserMaskingSetting(currentUser);
  const displayContact = ContactDisplayService.createDisplayContact(contact, shouldMask);

  Third-Order Effect: At high contact volumes (10k+ contacts), this could impact page load times

  5. Component Testing Complexity Explosion

  Second-Order Effect: Every contact-displaying component needs dual testing scenarios
  - Test with masking enabled
  - Test with masking disabled
  - Test edge cases (empty emails, malformed data)

  Third-Order Effect: Development velocity decreases, test maintenance burden increases

  6. Browser Console Security Risk

  Second-Order Effect: Real contact data still accessible via browser dev tools
  // In browser console, agents could still access:
  this.$store.getters['contacts/getContactById'](123).email

  Third-Order Effect: Determined agents can bypass masking, creating compliance issues

  🟢 LOW-IMPACT CONCERNS

  7. Training and Change Management

  Second-Order Effect: Agents need training on new interface behavior
  Third-Order Effect: Temporary productivity dip during transition period

  8. Feature Flag Management Complexity

  Second-Order Effect: Multiple configuration layers (feature flag + per-user setting)
  Third-Order Effect: Support complexity increases when troubleshooting issues

  🔥 CRITICAL HIDDEN RISKS

  9. Shopify Integration Data Flow Risk

  Analysis: While you mentioned Shopify integration uses backend data, there's a risk if any frontend components pass contact data to the integration:

  // If this pattern exists anywhere:
  const shopifyData = await fetchShopifyDetails({
    email: contact.display_email,  // WRONG - would send "[MASKED]"
    phone: contact.display_phone   // WRONG - would send "[MASKED]"
  });

  Mitigation: Audit all integration touchpoints to ensure they use real fields

  10. Contact Merge/Deduplication Edge Cases

  Risk: If UI components are used in contact merge workflows, masked data could interfere with merge decisions

  Example: Agent reviews potential duplicates but can't see emails to make informed merge decisions

  11. Copy/Paste Workflows Breaking

  Risk: Agents who rely on copying customer contact info will copy "[MASKED]" instead
  Impact: Customer communication outside Chatwoot becomes impossible

  📋 REQUIRED MITIGATIONS

  Essential Code Safeguards:

  1. Strict Component Patterns: Enforce display field usage in components
  2. Backend Integration Validation: Ensure all API calls use real data fields
  3. Console Protection: Implement CSP headers to limit dev tool access
  4. Contact Export Filtering: Separate export logic for masked vs unmasked users

  Essential Testing Requirements:

  1. Integration Tests: Verify Shopify and webhook integrations use real data
  2. Performance Tests: Load test with 10k+ contacts and masking enabled
  3. Security Tests: Verify data doesn't leak through browser APIs
  4. User Experience Tests: Test agent workflows with masking enabled

  Essential Documentation:

  1. Developer Guidelines: Clear patterns for display vs business logic fields
  2. Agent Training: Updated workflows for masked interface
  3. API Documentation: Clarify which endpoints return masked vs real data

  💡 ALTERNATIVE RECOMMENDATION

  Given these complexities, consider a Progressive Disclosure approach instead:

  1. Phase 1: Implement click-to-reveal masking (data hidden by default, click to show)
  2. Phase 2: Add audit logging for PII access
  3. Phase 3: Role-based reveal permissions

  This maintains security while preserving functionality and avoiding the dual-field complexity.

  🎯 IMPLEMENTATION DECISION FRAMEWORK

  Proceed with current plan if:
  - You can dedicate significant QA resources to testing
  - Agent productivity decrease is acceptable short-term
  - You have strong development team discipline for field usage patterns

  Consider alternatives if:
  - Limited QA resources
  - Agent efficiency is critical
  - Development team has junior members who might misuse fields

  Would you like me to detail the Progressive Disclosure approach as an alternative, or shall we proceed with implementing safeguards for the parallel
  fields approach?

> lets proceed with file level changes with the parallel fields approach. Dont make any changes to files yet. Just tell me exactly what you will do.
  ⎿  ☐ Plan exact file-level changes for parallel fields PII masking implementation
     ☐ Define backend feature flag and user settings changes
     ☐ Define frontend service and store modifications
     ☐ Define component-level UI updates
     ☐ Plan testing and validation files

● Exact File-Level Changes for Parallel Fields PII Masking

  Here's exactly what I will do to each file:

  🔧 BACKEND CHANGES

  1. /config/features.yml (MODIFY - line 172)

  Action: Add new feature flag entry
  - name: contact_pii_masking
    display_name: Contact PII Masking
    enabled: false

  2. /app/dashboards/user_dashboard.rb (MODIFY - 2 locations)

  Action A: Update ATTRIBUTE_TYPES hash (around line 10)
  - Add ui_settings: SerializedField to display PII masking toggle

  Action B: Update FORM_ATTRIBUTES array (around line 77)
  - Add :ui_settings to allow super admin editing

  3. /app/controllers/api/v1/profiles_controller.rb (MODIFY - update method)

  Action: Enhance update method (around line 15-25)
  - Add validation for mask_contact_pii permission
  - Add audit logging when PII masking setting changes
  - Ensure only authorized users can modify masking settings

  🎯 FRONTEND SERVICE LAYER

  4. /app/javascript/dashboard/services/ContactDisplayService.js (CREATE NEW)

  Action: Create complete service file
  - createDisplayContact(contact, shouldMask) method
  - maskEmail(email) method returning "[MASKED]"
  - maskPhone(phone) method returning "[MASKED]"
  - getContactIdentifier(contact) for alternative display
  - Validation methods for safe handling

  5. /app/javascript/dashboard/store/modules/contacts/getters.js (MODIFY - 2 functions)

  Action A: Update getContactsList function (around line 10)
  - Import ContactDisplayService
  - Check current user's masking setting
  - Apply parallel display fields to all contacts in list

  Action B: Update getContactById function (around line 20)
  - Same pattern as list getter
  - Apply masking to single contact retrieval

  6. /app/javascript/dashboard/composables/useContactDisplay.js (CREATE NEW)

  Action: Create composable file
  - getDisplayEmail(contact) method
  - getDisplayPhone(contact) method
  - getContactIdentifier(contact) method
  - isMaskingEnabled() computed property
  - Integration with auth store for user settings

  🎨 COMPONENT UPDATES

  7. /app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue (MODIFY - template section)

  Action: Update template (around lines 224-238)
  - Replace {{ contact.email }} with {{ getDisplayEmail(contact) }}
  - Replace {{ contact.phoneNumber }} with {{ getDisplayPhone(contact) }}
  - Import and use useContactDisplay composable

  8. /app/javascript/dashboard/components-next/Contacts/ContactsCard/ContactsCard.vue (MODIFY - template section)

  Action: Update template (around lines 114-122)
  - Replace direct email/phone display with display methods
  - Import useContactDisplay composable
  - Update computed properties if needed

  9. /app/javascript/dashboard/components/SearchResultContactItem.vue (MODIFY - template section)

  Action: Update template (around lines 58-62)
  - Replace contact email/phone display with masked versions
  - Import and use display methods
  - Ensure search highlighting still works with display data

  10. /app/javascript/dashboard/components/ContactIdentifier.vue (CREATE NEW)

  Action: Create component file
  - Display alternative identifier when data is masked
  - Show "Contact #123" or initials when email/phone hidden
  - Provide consistent fallback across app

  🔒 VALIDATION & SECURITY

  11. /app/services/pii_masking_validation_service.rb (CREATE NEW)

  Action: Create Rails service
  - validate_masking_request(user, settings) method
  - Feature flag validation
  - Permission checking
  - Fail-secure defaults

  12. /config/initializers/content_security_policy.rb (MODIFY OR CREATE)

  Action: Add/enhance CSP headers
  - Restrict console access in production
  - Prevent data extraction via dev tools
  - Add report-uri for CSP violations

  📝 CONFIGURATION & TESTING

  13. /app/javascript/dashboard/api/profiles.js (MODIFY - update method)

  Action: Enhance profile update method
  - Add specific handling for ui_settings.mask_contact_pii
  - Add validation for the setting
  - Ensure proper error handling

  14. /spec/services/pii_masking_validation_service_spec.rb (CREATE NEW)

  Action: Create comprehensive service tests
  - Test feature flag validation
  - Test permission checks
  - Test fail-secure behavior
  - Test edge cases

  15. /spec/javascript/dashboard/services/ContactDisplayService.spec.js (CREATE NEW)

  Action: Create frontend service tests
  - Test masking logic
  - Test parallel field creation
  - Test edge cases (null/undefined data)
  - Test performance with large datasets

  🔄 MIGRATION CONSIDERATIONS

  16. /app/javascript/dashboard/store/modules/auth/getters.js (MODIFY - if needed)

  Action: May need to add getter for masking setting
  - Add getPiiMaskingEnabled getter if not already accessible
  - Ensure UI settings are properly exposed

  17. /app/views/api/v1/models/_user.json.jbuilder (VERIFY - no changes expected)

  Action: Confirm ui_settings is already exposed
  - Ensure masking setting is included in API responses
  - No changes needed if already present

  📊 IMPACT SUMMARY

  Files Modified: 12 existing filesFiles Created: 5 new filesTotal Touch Points: 17 files

  Critical Integration Points:
  - Auth store integration (user settings)
  - Contact store integration (data transformation)
  - Component prop passing (display vs real data)
  - API endpoint updates (validation)

  Risk Mitigation Built-In:
  - Service layer abstraction for easy changes
  - Composable pattern for consistent usage
  - Server-side validation for security
  - Feature flag for safe rollout

  Testing Coverage:
  - Backend service tests
  - Frontend service tests
  - Component integration tests
  - API endpoint tests

  Would you like me to proceed with implementing these exact changes, or do you need clarification on any specific file modification?

> think deeply. will this:
  1. impact any existing chatwoot functionality
  2. completely and comprehensively mask all email ids and phone numbers for all agents who have been selected by the superadmin for masking.

✻ Thinking…

  Let me think deeply about both questions:

  1. Will this impact any existing chatwoot functionality?

  Looking at the parallel fields approach I've outlined, let me trace through the data flow:

  - Backend data remains unchanged (contact.email and contact.phone_number stay as-is)
  - Store getters add parallel display fields (contact.display_email, contact.display_phone)
  - Components use display fields for UI rendering
  - Business logic continues using real fields

  Potential impacts:
  - Search functionality: If components use display fields for search, this could break. Agents searching for "[MASKED]" won't find contacts.
  - Copy/paste workflows: Agents copying contact info will get "[MASKED]" strings
  - Contact forms: If any forms pre-populate with display fields, validation could fail
  - Export functionality: If exports use store getters, they might export masked data
  - API responses: The plan doesn't modify API responses, so external integrations should be safe
  - Browser console access: Real data still accessible via dev tools - security risk

  2. Will this completely and comprehensively mask all email ids and phone numbers?

  Let me think about all the places contact data appears:
  - Contact detail pages ✓ (ContactInfo.vue)
  - Contact cards ✓ (ContactsCard.vue)
  - Search results ✓ (SearchResultContactItem.vue)
  - Contact lists ✓ (via store getters)

  But what about:
  - Message sender information in conversation views?
  - Contact details in conversation sidebars?
  - Contact information in reports/analytics?
  - Contact data in automation rule displays?
  - Contact info in campaign interfaces?
  - Contact details in notification emails?
  - Mobile app displays (if any)?
  - Contact information in activity feeds?
  - Contact data in webhook configuration UIs?
  - Contact details in integration setup screens?

  I need to be more thorough. Let me think about this systematically...

  Actually, let me search for more components that might display contact data that I haven't covered.

● Task(Find all contact display components)
  ⎿  Done (31 tool uses · 75.0k tokens · 2m 53.3s)

✻ Thinking…

  This is extremely helpful. Now I can see that my original plan was incomplete. Let me analyze both questions thoroughly:

  Question 1: Will this impact any existing chatwoot functionality?

  Looking at the comprehensive list, I can see several potential impacts:

  1. Search functionality: The search components (SearchResultContactItem.vue, SearchResultConversationItem.vue) display email/phone. If these are
  masked, search results become less useful.
  2. Contact selection workflows: ContactSelector.vue and composeConversationHelper.js use email/phone to build display labels. If masked, agents can't
   distinguish between contacts.
  3. Contact merge functionality: ContactMergeForm.vue shows contact email for merge decisions. If masked, agents can't make informed merge choices.
  4. Message bubble displays: Contact.vue bubble shows phone numbers. This affects conversation context.
  5. Copy/paste workflows: All these components would output "[MASKED]" when agents copy contact info.
  6. Export functionality: If any export features use these display components or store getters, they'd export masked data.
  7. Search/filter functionality: If the search backend relies on frontend queries that include the display fields, it could break.

  Question 2: Will this completely mask all email/phone?

  Looking at the comprehensive list, my original plan would NOT completely mask everything. I only covered 3 components but there are at least 11+
  components that display contact PII:

  Components I covered:
  1. ✅ ContactInfo.vue
  2. ✅ ContactsCard.vue
  3. ✅ SearchResultContactItem.vue

  Components I MISSED:
  4. ❌ ContactInfoRow.vue (CRITICAL - this is the actual renderer)
  5. ❌ SearchResultConversationItem.vue
  6. ❌ ContactDropdownItem.vue
  7. ❌ Contact.vue (message bubble)
  8. ❌ ContactMergeForm.vue

  9. ❌ EditContact.vue
  10. ❌ ContactSelector.vue
  11. ❌ composeConversationHelper.js

  I'm uncovering significant implementation gaps. The masking strategy would be fragmented and inconsistent across multiple interface points. Targeting
   ContactInfoRow.vue as the central rendering component could provide a more comprehensive solution, since many other components rely on its data
  presentation logic.

  The potential scope of incomplete masking extends beyond just UI components. I need to investigate additional areas like mobile interfaces,
  administrative dashboards, reporting systems, and integration configuration screens that might expose sensitive contact information.

  Potential unmasked contact data exposure zones include notification systems, activity feeds, campaign management interfaces, and email template
  configurations. Each represents a potential vulnerability in the data privacy implementation.

● Deep Analysis: Critical Issues with Current Plan

  ❌ QUESTION 1: WILL THIS IMPACT EXISTING FUNCTIONALITY?

  YES - SIGNIFICANT FUNCTIONALITY IMPACT

  CRITICAL FUNCTIONAL BREAKDOWNS:

  1. Contact Search & Selection Becomes Unusable
    - ContactSelector.vue (lines 63, 76-78) builds contact labels with email/phone
    - composeConversationHelper.js (lines 22, 28, 206) filters contacts by PII
    - Impact: Agents can't distinguish between contacts when selecting for new conversations
  2. Contact Merge Decisions Impossible
    - ContactMergeForm.vue (line 107) shows email for merge decisions
    - Impact: Agents can't make informed merge choices without seeing contact identifiers
  3. Search Results Become Meaningless
    - SearchResultConversationItem.vue (line 65, 126) shows contact email in search results
    - Impact: Search loses primary identification method
  4. Conversation Context Loss
    - Contact.vue bubble (line 94) shows phone numbers in conversation context
    - Impact: Agents lose important conversation context about customer contact method
  5. Copy/Paste Workflows Break
    - All components output "[MASKED]" strings
    - Impact: Agents can't copy real contact info for external communication

  ❌ QUESTION 2: WILL THIS COMPLETELY MASK ALL PII?

  NO - MASSIVE COVERAGE GAPS

  COMPONENTS I MISSED (Incomplete Masking):

  My original plan only covered 3 components but there are 11+ components displaying PII:

  ✅ Covered (3 components):
  - ContactInfo.vue
  - ContactsCard.vue
  - SearchResultContactItem.vue

  ❌ MISSED (8+ critical components):
  1. ContactInfoRow.vue - MOST CRITICAL (actual PII renderer)
  2. SearchResultConversationItem.vue - Shows contact email in search
  3. ContactDropdownItem.vue - Contact selection dropdowns
  4. Contact.vue - Message bubble contact display
  5. ContactMergeForm.vue - Contact merge interface
  6. EditContact.vue - Contact edit modal headers
  7. ContactSelector.vue - New conversation contact selection
  8. composeConversationHelper.js - Contact labeling logic

  ADDITIONAL GAPS I HAVEN'T ANALYZED:

  - Contact export interfaces
  - Analytics/reporting displays
  - Campaign management contact lists
  - Automation rule contact displays
  - Mobile app components
  - Email notification templates
  - Activity feed contact mentions
  - Integration configuration screens

  🚨 ROOT CAUSE: FLAWED ARCHITECTURE

  The fundamental issue is that contact PII is displayed everywhere in Chatwoot. My approach of modifying individual components is:

  1. Incomplete - I can't catch every display location
  2. Fragile - New components will bypass masking
  3. Inconsistent - Some places masked, others not
  4. Breaking - Core workflows depend on seeing contact identifiers

  💡 RECOMMENDED ARCHITECTURE CHANGE

  Instead of component-by-component masking, implement centralized masking at the ContactInfoRow level:

  Better Approach:

  1. Mask at ContactInfoRow.vue (the actual renderer)
  2. Create contact identification alternatives (Contact #123, Customer A.B.)
  3. Preserve search functionality with masked-safe identifiers
  4. Add hover/click reveal for authorized actions

  Alternative: Server-Side Selective Serialization

  - Modify /app/views/api/v1/models/_contact.json.jbuilder
  - Return masked data for agents, real data for system functions
  - Frontend never receives real PII for masked users

  🎯 DEFINITIVE ANSWERS:

  1. Will this impact functionality? YES - Search, contact selection, merge workflows, and copy/paste will be significantly degraded
  2. Will this completely mask PII? NO - At least 8 major components would still show real email/phone numbers

  📋 RECOMMENDATION:

  PAUSE current implementation plan. The component-by-component approach is architecturally flawed.

  Would you like me to:
  1. Redesign with server-side masking (cleaner, more complete)
  2. Redesign with ContactInfoRow-level masking (simpler, fewer changes)
  3. Continue with comprehensive component coverage (high-risk, complex)

  Which direction should we take?

> Lets focus on the functionality impact first.
  I am OK if agents are unable to merge conversations. I assume that they will be able to search by some other identifier if we provide it (lets not
  focus on that at the moment. Later it can be the shopify order name).
  Copy/paste workflows are intended to break (we ll let them copy the shopify order names... and that would mitigate the negative impact).
  any other functionality impact?

● Task(Analyze contact-dependent workflows)
  ⎿  Done (30 tool uses · 70.9k tokens · 2m 52.9s)

● Additional Functionality Impact Analysis

  Based on the comprehensive workflow analysis, here are the other critical functionality impacts:

  🔴 CRITICAL WORKFLOW BREAKS

  1. Contact Search & Filtering - Core Agent Function

  - Impact: Agents lose primary contact identification method
  - Frequency: Used dozens of times daily by every agent
  - Workflow: "Find customer by email" becomes impossible
  - Mitigation Needed: Must provide alternative search identifiers

  2. New Conversation Creation - Channel Selection Broken

  // This logic breaks when email/phone are "[MASKED]"
  if (channelType === INBOX_TYPES.EMAIL) {
    return `${name} (${email})`;  // Shows "[MASKED]"
  }
  - Impact: Agents can't distinguish between email/SMS contacts
  - Workflow: Creating new conversation becomes guesswork
  - Critical: Channel routing depends on seeing real contact method

  3. Contact Verification in Active Conversations

  - Impact: Agents can't verify they're talking to the right customer
  - Workflow: Customer says "this is mailto:john@company.com" but agent sees "[MASKED]"
  - Risk: Wrong customer conversations, privacy violations

  4. Automation Rules Configuration

  - Impact: Agents can't create email/phone-based automation rules
  - Example: "If email contains @vip-company.com, assign to senior agent"
  - Workflow: Rule creation interface becomes non-functional for PII criteria

  5. Integration Feature Dependencies

  // Shopify integration breaks if no searchable contact info
  const hasSearchableInfo = computed(
    () => !!contact.value?.email || !!contact.value?.phone_number
  );
  - Impact: Shopify order lookup feature stops working
  - Irony: This contradicts your Shopify integration requirement

  🟡 MODERATE WORKFLOW IMPACTS

  6. Contact Data Quality Management

  - Impact: Agents can't spot duplicate/incorrect contact data
  - Workflow: Data cleanup becomes impossible without seeing PII

  7. Click-to-Call/Email Functionality

  - Impact: Direct communication buttons become non-functional
  - Workflow: Agents lose quick communication shortcuts

  8. Contact Import/Export Validation

  - Impact: Agents can't verify imported contact data accuracy
  - Workflow: Data import QA process breaks

  🟢 ACCEPTABLE BREAKS (Per Your Requirements)

  ✅ Contact Merging - You confirmed this is acceptable✅ Copy/Paste Workflows - You confirmed this is intended✅ Contact Selection Ambiguity - You
  plan to use Shopify order names

  🚨 SHOWSTOPPER CONTRADICTION

  Critical Issue: The Shopify integration depends on hasSearchableInfo which checks for email/phone. Masking these would break the very integration you
   need to preserve:

  // This would become false when email/phone are masked
  const hasSearchableInfo = computed(
    () => !!contact.value?.email || !!contact.value?.phone_number  // Both "[MASKED]"
  );

  📋 SUMMARY OF ALL FUNCTIONALITY IMPACTS

  Core Agent Functions That Break:
  1. Contact search by email/phone ❌
  2. New conversation channel selection ❌
  3. Contact verification in conversations ❌
  4. Automation rule configuration ❌
  5. Shopify integration feature detection ❌
  6. Contact data quality management ❌
  7. Direct communication shortcuts ❌

  Functions You Accept Breaking:
  1. Contact merging ✅
  2. Copy/paste workflows ✅

  Functions Requiring Mitigation:
  1. Alternative contact identifiers for search
  2. Alternative contact verification method
  3. Shopify integration compatibility fix

  🎯 KEY QUESTION

  The Shopify integration conflict is critical - the frontend feature detection will break when it can't see email/phone. How should we handle this
  contradiction?

  Options:
  1. Fix the integration to work with masked data
  2. Exclude Shopify users from PII masking
  3. Use backend-only Shopify integration (no frontend component)

  Which approach do you prefer for resolving the Shopify integration conflict?

> we ll use backend only shopify integration and surface the non PII data to the agents on the front end. this non PII data will be searchable.
  for the channel selection, just mention the channel instead of the PII in the label so that the agent knows. contact verification is going to be done
   at the backend by shopify and the relevant order details will be available to the agent. The communication will be around these order details only,
  so dont think that should be an issue.
  we should be able to do automatic rule configuration based on shopify order data, right. we should not need PII for that to be visible to the agent.
  Is there anything else I am missing?

✻ Thinking…

  The user is providing good clarifications on how they plan to handle the functionality impacts I identified. Let me analyze their responses:

  1. Shopify integration: Backend-only with non-PII data surfaced to frontend that's searchable - this makes sense and resolves the contradiction I
  identified.
  2. Channel selection: Show channel type instead of PII in labels - reasonable solution.
  3. Contact verification: Done via backend Shopify integration with order details shown to agents - this could work.
  4. Communication context: Will be around order details instead of PII - makes sense for e-commerce use case.
  5. Automation rules: Based on Shopify order data instead of PII - should be feasible.

  Now I need to think if there are any other critical functionality impacts they're missing. Let me think through some additional scenarios:

  1. Multi-channel contact management: What if a customer contacts via email AND SMS? How will agents know it's the same person without seeing PII?
  This could be resolved by Shopify customer ID linking.
  2. Non-Shopify customers: What about contacts who don't have Shopify orders? How will agents identify/search for them? This could be a significant
  gap.
  3. Contact deduplication: Backend processes might create duplicate contacts because the frontend can't see duplicates to merge them. But the user
  said merging is acceptable to break.
  4. Conversation routing: When a new message comes in from an email/phone, how will it be routed to the right agent if they can't see the identifier?
  This should work backend though.
  5. Agent training and transition: Agents will need significant retraining on new workflows.
  6. Compliance and audit: How will they prove PII masking is working if there are any gaps?
  7. Contact data updates: If a customer says "please update my email to mailto:new@email.com", how will agents handle this without seeing current
  email?
  8. Non-e-commerce use cases: What if some accounts don't use Shopify? Will they lose all contact identification?

  I'm concerned about potential technical challenges that could disrupt agent workflows. Performance and system reliability are critical. The Shopify
  integration might introduce significant operational risks, with potential API latency and availability issues that could completely block agent
  interactions. These technical dependencies could create major friction in customer support processes.

● Analyzing Your Mitigation Strategy

  Your approach addresses the major concerns well, but there are 3 critical gaps you may be missing:

  🚨 CRITICAL MISSING SCENARIOS

  1. Non-Shopify Customers (Orphaned Contacts)

  Scenario: Customers who contact you but haven't placed Shopify orders yet
  - Problem: No Shopify data = No searchable identifier = Completely invisible to agents
  - Impact: New prospects, pre-purchase inquiries, or customers from other channels become unmanageable
  - Question: How will agents identify and search for contacts with no Shopify order history?

  2. Contact Data Updates & Corrections

  Scenario: Customer says "Please update my email from mailto:old@email.com to mailto:new@email.com"
  - Problem: Agent sees "[MASKED]" and can't verify current email or confirm the change
  - Impact: Data integrity issues, customer frustration, potential wrong updates
  - Question: How will agents handle contact information updates without seeing current data?

  3. Multi-Channel Contact Linking

  Scenario: Customer emails from work, then texts from personal phone about same order
  - Problem: Without PII visibility, agents may not realize it's the same customer
  - Impact: Fragmented conversation history, duplicate responses, poor customer experience
  - Question: How will agents link conversations from different channels to same customer?

  🟡 MODERATE CONCERNS

  4. System Performance & Reliability

  - Shopify API dependency: Every contact interaction requires Shopify lookup
  - Failure scenarios: What happens when Shopify API is down/slow?
  - Scale impact: Will Shopify API rate limits affect agent productivity?

  5. Agent Workflow Complexity

  - Learning curve: Agents must learn entirely new identification system
  - Efficiency impact: Longer customer identification process
  - Error potential: More steps = more chances for mistakes

  🟢 YOUR SOLUTIONS WORK FOR

  ✅ Channel selection: Showing channel type instead of PII✅ Contact verification: Via Shopify order details✅ Communication context: Around order
  details✅ Automation rules: Based on Shopify data✅ Shopify integration: Backend-only approach

  🎯 KEY QUESTIONS TO RESOLVE

  1. Non-Shopify contacts: What's your fallback identification strategy?
  2. Contact updates: How will agents manage PII changes without seeing current data?
  3. Cross-channel linking: How will you ensure conversation continuity across channels?

  💡 POTENTIAL SOLUTIONS

  For Non-Shopify Contacts:

  - Generate unique contact IDs (CONT-1234)
  - Use first name + last initial + creation date
  - Implement contact tagging system for identification

  For Contact Updates:

  - Backend validation workflows
  - Admin-only contact editing capabilities
  - Customer self-service portal for updates

  For Cross-Channel Linking:

  - Backend algorithms to link channels by Shopify customer ID
  - Conversation threading based on order numbers
  - Agent notifications for potential same-customer contacts

  📋 IMPLEMENTATION DECISION

  These gaps are manageable but require additional planning. The core masking approach is still viable if you address:

  1. Non-Shopify contact identification strategy
  2. Contact data update workflows
  3. Cross-channel conversation linking

  Should we proceed with the implementation and build these missing pieces, or do you want to design solutions for these scenarios first?

> lets design solutions for these scenarios first. your potential solutions look interesting. analyze them and give me the best approach.
  ⎿  ☐ Design solutions for non-Shopify contact identification
     ☐ Design contact data update workflows
     ☐ Design cross-channel conversation linking
     ☐ Analyze implementation complexity for each solution

● Comprehensive Solution Design & Analysis

  🎯 SOLUTION 1: NON-SHOPIFY CONTACT IDENTIFICATION

  Option A: Unique Contact IDs (RECOMMENDED)

  // Example: CONT-2024-1234, CUST-A1B2C3
  displayIdentifier: generateContactId(contact.id, contact.created_at)

  ✅ Pros:
  - Always unique and available
  - No external dependencies
  - Simple to implement and understand
  - Scales infinitely

  ❌ Cons:
  - Not human-memorable
  - No semantic meaning for agents

  Implementation Complexity: LOW

  Option B: Name + Identifier Hybrid

  // Example: "John D. #1234", "Sarah M. (Dec-15)"
  displayIdentifier: `${firstName} ${lastName[0]}. #${contact.id}`

  ✅ Pros:
  - More human-friendly
  - Combines recognizable name with unique ID
  - Agents can remember frequent customers

  ❌ Cons:
  - Fails when names are missing/duplicate
  - Privacy concern (still shows partial PII)
  - Complex fallback logic needed

  Implementation Complexity: MEDIUM

  Option C: Contact Tagging System

  // Example: "VIP-Customer", "Website-Lead", "Support-Inquiry"
  displayIdentifier: contact.primary_tag || `CONT-${contact.id}`

  ✅ Pros:
  - Semantic meaning for agents
  - Flexible categorization
  - Supports business workflows

  ❌ Cons:
  - Requires manual tagging effort
  - Inconsistent if agents forget to tag
  - Tags may not be unique

  Implementation Complexity: HIGH

  🔄 SOLUTION 2: CONTACT DATA UPDATE WORKFLOWS

  Option A: Backend Validation + Admin Approval (RECOMMENDED)

  # Workflow: Customer requests update → System validates → Admin approves → Update applied
  class ContactUpdateRequest
    def create_update_request(contact, proposed_changes, source)
      # Validate proposed email/phone format
      # Create pending update record
      # Notify admin for approval
      # Send confirmation to customer
    end
  end

  ✅ Pros:
  - Maintains data integrity
  - Clear audit trail
  - Prevents fraudulent updates
  - Complies with data protection

  ❌ Cons:
  - Introduces delay for customers
  - Requires admin intervention
  - More complex workflow

  Implementation Complexity: MEDIUM

  Option B: Customer Self-Service Portal

  // Customer updates own data via secure portal
  // System validates and auto-applies if confidence is high
  const selfServiceUpdate = {
    emailVerification: true,  // Send verification email
    phoneVerification: true, // Send SMS code
    autoApprove: validationScore > 0.8
  }

  ✅ Pros:
  - No agent/admin involvement needed
  - Fast customer experience
  - Reduces support burden

  ❌ Cons:
  - Requires building separate portal
  - Security/verification complexity
  - May not integrate well with existing flow

  Implementation Complexity: HIGH

  Option C: Hybrid Agent-Assisted Updates

  // Agent initiates backend update without seeing current data
  const updateFlow = {
    1: "Customer requests change",
    2: "Agent creates update ticket",
    3: "System emails customer verification link",
    4: "Customer confirms → Update applied"
  }

  ✅ Pros:
  - Agents stay involved in process
  - Secure verification method
  - Maintains customer relationship

  ❌ Cons:
  - Multi-step process
  - Delays resolution
  - Email delivery dependencies

  Implementation Complexity: MEDIUM

  🔗 SOLUTION 3: CROSS-CHANNEL CONVERSATION LINKING

  Option A: Backend Shopify Customer ID Matching (RECOMMENDED)

  # Automatic linking based on Shopify customer records
  class CrossChannelLinker
    def link_conversations(new_contact)
      shopify_customer = ShopifyService.find_customer_by_contact(new_contact)
      if shopify_customer
        existing_contacts = Contact.where(shopify_customer_id: shopify_customer.id)
        link_conversations_for_contacts(existing_contacts + [new_contact])
      end
    end
  end

  ✅ Pros:
  - Fully automated
  - Highly accurate (Shopify customer ID is authoritative)
  - No agent intervention needed
  - Preserves conversation history

  ❌ Cons:
  - Only works for Shopify customers
  - Depends on Shopify API availability
  - Complex backend logic

  Implementation Complexity: MEDIUM

  Option B: Agent Notification + Manual Linking

  // Show agent potential matches when new conversation starts
  const similarContacts = {
    message: "Potential match found: Customer with Order #1234 contacted via email 2 days ago",
    action: "Link Conversations",
    confidence: "High"
  }

  ✅ Pros:
  - Agent maintains control
  - Works for all contact types
  - Can handle edge cases

  ❌ Cons:
  - Requires agent action
  - Inconsistent application
  - Interrupts workflow

  Implementation Complexity: LOW

  Option C: Order Number Context Matching

  // Automatic linking when customer mentions order numbers
  const contextMatcher = {
    pattern: /order.*#?(\d{4,})/i,
    action: "auto_link_conversations_with_same_order",
    notification: "Linked to previous conversation about Order #1234"
  }

  ✅ Pros:
  - Automatic and context-aware
  - High accuracy when order numbers mentioned
  - Good customer experience

  ❌ Cons:
  - Only works when customers mention orders
  - Pattern matching can have false positives
  - Doesn't work for pre-purchase inquiries

  Implementation Complexity: MEDIUM

  🏆 RECOMMENDED BEST-OF-BREED SOLUTION

  Phase 1: Core Infrastructure (MVP)

  1. Unique Contact IDs for non-Shopify contacts (CONT-2024-1234)
  2. Backend validation workflow for contact updates with admin approval
  3. Shopify Customer ID matching for automatic cross-channel linking

  Phase 2: Enhanced Experience

  1. Agent notification system for potential conversation matches
  2. Order number context matching for intelligent linking
  3. Customer self-service portal for data updates

  Phase 3: Advanced Features

  1. Contact tagging system for semantic identification
  2. Predictive linking algorithms using conversation patterns
  3. Automated confidence scoring for update approvals

  📊 IMPLEMENTATION ROADMAP

  Total Implementation Effort:
  - Phase 1: 3-4 weeks (essential for PII masking)
  - Phase 2: 2-3 weeks (improved UX)
  - Phase 3: 4-5 weeks (advanced features)

  Critical Dependencies:
  - Shopify API integration architecture
  - Contact update approval system
  - Cross-channel conversation data model

  Risk Mitigation:
  - Start with Phase 1 (simplest, most reliable)
  - Test extensively with Shopify integration
  - Build fallbacks for all automated systems

  🎯 DECISION POINT

  Recommended Minimum Viable Solution:
  1. Contact IDs for identification
  2. Backend validation for updates
  3. Shopify-based conversation linking

  This provides complete coverage for your PII masking needs while maintaining functionality.

  Should we proceed with detailed implementation planning for Phase 1, or do you want to modify any of these approaches?

> we will not attempt to slove for points 2 and 3 till the shopify integration is up and running. Lets put a pin on those.
  for point 1, lets go ahead with option B, and in the absence of missing names, fallback to option A. will that work. Do not make any changes yet.
  ⎿  Invalid tool parameters
  ⎿  ☐ Analyze hybrid non-Shopify contact identification approach
     ☐ Complete PII masking implementation with contact ID solution
     ☐ Validate fallback logic for contact identification

● Analysis: Hybrid Contact Identification Approach

  YES, this hybrid approach will work very well. Here's my detailed analysis:

  🎯 HYBRID STRATEGY: Option B → Option A Fallback

  Primary Approach (Option B): Name + Identifier

  // Example outputs:
  "John D. #1234"
  "Sarah M. #5678"
  "Michael Johnson #9012"

  Fallback Approach (Option A): Unique Contact IDs

  // When names missing/inadequate:
  "CONT-2024-1234"
  "CUST-A1B2C3"

  ✅ WHY THIS WORKS PERFECTLY

  1. Covers All Edge Cases

  - Complete names: "John Doe #1234" (most human-friendly)
  - First name only: "John #1234" (still recognizable)
  - Last name only: "Doe #1234" (better than nothing)
  - No names: "CONT-2024-1234" (reliable fallback)
  - Duplicate names: Unique ID differentiates them

  2. Privacy-Friendly

  - Uses only first name + last initial (minimal PII exposure)
  - Much less sensitive than email/phone
  - Acceptable privacy compromise for functionality

  3. Agent-Friendly

  - Human-readable for most contacts
  - Memorable for frequent customers
  - Clear fallback pattern when names unavailable

  🔧 IMPLEMENTATION LOGIC

  Contact Display Service Method:

  generateContactIdentifier(contact) {
    const { name, first_name, last_name, id, created_at } = contact;

    // Strategy 1: Full name available
    if (first_name && last_name) {
      return `${first_name} ${last_name[0]}. #${id}`;
    }

    // Strategy 2: First name only
    if (first_name) {
      return `${first_name} #${id}`;
    }

    // Strategy 3: Last name only
    if (last_name) {
      return `${last_name} #${id}`;
    }

    // Strategy 4: Generic name field
    if (name && name.trim()) {
      const parts = name.trim().split(' ');
      if (parts.length > 1) {
        return `${parts[0]} ${parts[parts.length-1][0]}. #${id}`;
      }
      return `${parts[0]} #${id}`;
    }

    // Fallback: Unique contact ID
    return `CONT-${new Date(created_at).getFullYear()}-${id}`;
  }

  📊 COVERAGE ANALYSIS

  Expected Distribution:

  - 70% - Full names: "John D. #1234"
  - 15% - Partial names: "John #1234"
  - 10% - Generic names: "CompanyName #1234"
  - 5% - Fallback IDs: "CONT-2024-1234"

  Search Functionality:

  - Agents can search by first name + ID
  - Agents can search by ID number alone
  - System can index both name and ID components

  🚨 POTENTIAL CHALLENGES & SOLUTIONS

  Challenge 1: Name Normalization

  Issue: Names like "john doe jr.", "Mary-Jane", "O'Connor"
  Solution: Simple preprocessing - capitalize, handle special chars gracefully

  Challenge 2: Very Long Names

  Issue: "Constantine Alexandroupolis" becomes unwieldy
  Solution: Truncate first name to 10 chars max

  Challenge 3: Non-Latin Characters

  Issue: Names with accents, Asian characters, etc.
  Solution: Use Unicode-safe processing, fallback to ID if rendering issues

  Challenge 4: Duplicate Display Names

  Issue: Multiple "John D. #different-ids"
  Solution: ID suffix always makes them unique

  🎯 INTEGRATION WITH CURRENT PLAN

  This fits perfectly into our existing implementation:

  Updated ContactDisplayService:

  static createDisplayContact(contact, shouldMask = false) {
    const displayContact = { ...contact };

    if (shouldMask) {
      displayContact.displayEmail = "[MASKED]";
      displayContact.displayPhone = "[MASKED]";
      displayContact.displayIdentifier = this.generateContactIdentifier(contact);
    } else {
      displayContact.displayEmail = contact.email;
      displayContact.displayPhone = contact.phoneNumber;
      displayContact.displayIdentifier = contact.email || contact.phoneNumber || this.generateContactIdentifier(contact);
    }

    return displayContact;
  }

  Component Usage:

  <template>
    <!-- Instead of showing email/phone -->
    <span class="contact-identifier">{{ contact.displayIdentifier }}</span>
  </template>

  📋 IMPLEMENTATION READINESS

  This approach is:
  - ✅ Technically feasible - Simple logic, no external dependencies
  - ✅ Privacy compliant - Minimal PII exposure
  - ✅ User-friendly - Human-readable most of the time
  - ✅ Scalable - Works for any number of contacts
  - ✅ Search-compatible - Can index and search both name and ID parts

  🚀 READY TO PROCEED

  The hybrid approach elegantly solves the non-Shopify contact identification problem and integrates seamlessly with the PII masking implementation.

  Shall we proceed with the complete file-level implementation plan that includes this contact identification strategy?

> yes. recap the objectives first. Once i give the go ahead on that, lets proceed with the complete file level implementation plan.

● 📋 OBJECTIVES RECAP

  PRIMARY GOAL:

  Mask email IDs and phone numbers for all agents in Chatwoot while preserving all application functionality.

  SPECIFIC REQUIREMENTS:

  1. WHO:

  - All agents selected by super admin for masking
  - Per-agent setting configurable only by super admin
  - Feature flag controlled (regular functionality, not premium)

  2. WHAT TO MASK:

  - Email addresses → "[MASKED]"
  - Phone numbers → "[MASKED]"
  - Scope: All existing and new contacts
  - Exception: Message history is exempt from masking

  3. WHERE TO MASK:

  - Web dashboard UI only - APIs and backend continue normally
  - All contact display components throughout the application

  4. FUNCTIONALITY PRESERVATION:

  - Backend operations continue unchanged (email routing, SMS delivery, etc.)
  - Shopify integration will be backend-only, surfacing non-PII data to frontend
  - Channel communication must work normally (email, SMS, WhatsApp)
  - Contact deduplication and business logic preserved

  5. ACCEPTABLE FUNCTIONALITY CHANGES:

  - ✅ Contact merging - Agents unable to merge (acceptable)
  - ✅ Copy/paste workflows - Intentionally broken (will use Shopify order names)
  - ✅ Contact search by email/phone - Will use alternative identifiers

  6. ALTERNATIVE IDENTIFICATION SYSTEM:

  - For Shopify customers: Shopify order names/numbers (future implementation)
  - For non-Shopify contacts: Hybrid approach
    - Primary: "John D. #1234" (first name + last initial + ID)
    - Fallback: "CONT-2024-1234" (when names missing)

  7. POSTPONED FEATURES:

  - Contact data updates - Will solve after Shopify integration
  - Cross-channel conversation linking - Will solve after Shopify integration

  TECHNICAL APPROACH:

  - Parallel display fields - Preserve real data for business logic, show masked data in UI
  - Component-level masking using centralized service
  - Feature flag + user settings for super admin control
  - Comprehensive component coverage across all contact display areas

  SUCCESS CRITERIA:

  1. Zero breaking changes to core Chatwoot functionality
  2. Complete PII masking for selected agents in UI
  3. Alternative contact identification working for all scenarios
  4. Super admin control interface functional
  5. Backend systems continue operating normally

  ---
  🎯 CONFIRMATION REQUIRED

  Do these objectives accurately capture your requirements?

  Any adjustments needed before we proceed with the complete file-level implementation plan?

  Once you confirm, I'll provide the detailed file-by-file implementation plan with the hybrid contact identification system integrated.
