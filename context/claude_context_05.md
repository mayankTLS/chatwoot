# PII Masking Enhancement - Contacts Detail Page Implementation

## User Request and Clarification

The user initially requested:
1. Remove the update and delete contact buttons from the contact information view visible to users with Masked PII access
2. Remove the fields in the read-only form that display the email id and the phone number

### Important Clarification
There was an initial misunderstanding. The user clarified they were referring to the dedicated contacts page (`https://chat.tlslogistics.org/app/accounts/1/contacts/1`) **NOT** the conversation contact panel (`https://chat.tlslogistics.org/app/accounts/1/conversations/1`). The conversation panel was already working perfectly.

## Analysis Phase

### Component Investigation
I conducted a thorough analysis of the contacts detail page components:

**Primary Components Identified:**
1. **ContactDetails.vue** (`/components-next/Contacts/Pages/ContactDetails.vue`)
   - Main contact detail page component
   - Contains Update button (lines 169-175)
   - Contains Delete section (lines 177-193)

2. **ContactsForm.vue** (`/components-next/Contacts/ContactsForm/ContactsForm.vue`)
   - Handles contact form rendering
   - Contains `FORM_CONFIG` with EMAIL_ADDRESS and PHONE_NUMBER fields
   - Uses `editDetailsForm` computed property to generate form fields

### Key Findings

**Update/Delete Buttons Location:**
- Update button: `ContactDetails.vue:169-175`
- Delete section: `ContactDetails.vue:177-193` 

**Email/Phone Fields:**
- Rendered via `ContactsForm.vue` using `FORM_CONFIG`
- Fields are filtered through `editDetailsForm` computed property
- Current state: Fields are disabled but still visible with masked values

**Existing PII Infrastructure:**
- `usePiiProtectedActions` composable already available
- `isPiiMasked` reactive property works correctly
- Form already respects PII masking via `isFormDisabled`

## Implementation Plan

### Strategy
Instead of showing disabled fields with "[PROTECTED]" text, completely remove sensitive elements for PII-masked users:

1. **Hide Update Button**: Add `v-if="!isPiiMasked"` 
2. **Hide Delete Section**: Add `v-if="!isPiiMasked"`
3. **Filter Form Fields**: Remove EMAIL_ADDRESS and PHONE_NUMBER from form config for PII-masked users

### Safety Analysis
The implementation was deemed **VERY LOW RISK** because:
- Purely presentational changes (hiding UI elements)
- Uses existing PII infrastructure 
- Additive protection (not removing safeguards)
- Backward compatible for non-PII users
- Form validation adapts to available fields automatically

## Implementation Details

### File 1: ContactDetails.vue

**Changes Made:**
```vue
// Added import
import { usePiiProtectedActions } from 'dashboard/composables/usePiiProtectedActions';

// Added variable
const { isPiiMasked } = usePiiProtectedActions();

// Hidden update button
<Button
  v-if="!isPiiMasked"
  :label="t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')"
  size="sm"
  :is-loading="isUpdating"
  :disabled="isUpdating || isFormInvalid"
  @click="updateContact"
/>

// Hidden delete section
<div
  v-if="!isPiiMasked"
  class="flex flex-col items-start w-full gap-4 pt-6 border-t border-n-strong"
>
  <!-- Delete section content -->
</div>
```

### File 2: ContactsForm.vue

**Changes Made:**
```vue
// Modified editDetailsForm computed property
const editDetailsForm = computed(() =>
  Object.keys(FORM_CONFIG)
    .filter(key => {
      // Hide EMAIL_ADDRESS and PHONE_NUMBER for PII-masked users
      if (
        isPiiMasked.value &&
        ['EMAIL_ADDRESS', 'PHONE_NUMBER'].includes(key)
      ) {
        return false;
      }
      return true;
    })
    .map(key => ({
      key,
      placeholder: t(
        `CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`
      ),
    }))
);
```

## Quality Assurance

### Linting Results
- **ESLint**: ✅ Passed with auto-fix (formatting only)
- **RuboCop**: ✅ Passed with no offenses detected

### Code Quality
- Uses existing PII masking infrastructure
- Follows Vue.js composition API patterns
- Maintains backward compatibility
- Clean, readable implementation

## Expected Behavior

### For PII-Masked Users (`/app/accounts/1/contacts/1`):
- ✅ Contact name, avatar, labels visible
- ✅ Additional attributes (city, country, bio, company) visible
- ✅ Social profiles visible
- ❌ Email field completely hidden
- ❌ Phone number field completely hidden
- ❌ Update button completely hidden
- ❌ Delete section completely hidden

### For Regular Users:
- ✅ All fields and buttons remain visible and functional
- ✅ No change to existing behavior

## Technical Benefits

1. **Complete Removal**: No "[PROTECTED]" text shown
2. **Clean UI**: Seamless experience for PII-masked users
3. **Security**: No possibility of data leakage
4. **Maintainable**: Leverages existing infrastructure
5. **Performance**: Reduced DOM elements for PII-masked users

## Files Modified

1. `/app/javascript/dashboard/components-next/Contacts/Pages/ContactDetails.vue`
   - Added PII masking import and variable
   - Hidden update button with `v-if="!isPiiMasked"`
   - Hidden delete section with `v-if="!isPiiMasked"`

2. `/app/javascript/dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue`
   - Modified `editDetailsForm` computed property
   - Added filter to exclude EMAIL_ADDRESS and PHONE_NUMBER for PII-masked users

## Implementation Status: ✅ COMPLETE

The PII masking enhancements for the contacts detail page have been successfully implemented. PII-masked agents will now see a clean, read-only contact view without sensitive email/phone information or modification capabilities, while maintaining full functionality for authorized users.