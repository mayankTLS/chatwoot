import { computed, ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import {
  maskEmail as maskEmailUtil,
  maskPhone as maskPhoneUtil,
  shouldMaskData,
  getMaskingPattern,
  maskEmailList,
  createRevealHandler,
} from 'shared/helpers/maskingHelper';

/**
 * Vue composable for handling data masking functionality
 * Provides reactive masking capabilities with permission awareness
 */
export const useMasking = () => {
  const { isCloudFeatureEnabled } = useAccount();

  // Get current user and account settings
  const currentUser = useMapGetter('getCurrentUser');
  const currentAccount = useMapGetter('getCurrentAccount');

  // Reactive masking state
  const revealStates = ref(new Map());

  // Compute account masking settings
  const accountMaskingSettings = computed(() => {
    return (
      currentAccount.value?.settings?.masking || {
        masking_enabled: true, // Default to true
        masking_rules: {
          email: { enabled: true, pattern: 'standard' },
          phone: { enabled: true, pattern: 'standard' },
          admin_bypass: false, // Don't bypass for admins by default
          exempt_roles: [], // No roles exempt by default
        },
      }
    );
  });

  // Check if user can view sensitive data
  const canViewSensitiveData = computed(() => {
    const user = currentUser.value;
    const settings = accountMaskingSettings.value;

    // If masking is disabled, everyone can see data
    if (!settings?.masking_enabled) {
      return true;
    }

    // Admin bypass (only if explicitly enabled)
    if (
      user?.type === 'administrator' &&
      settings?.masking_rules?.admin_bypass === true
    ) {
      return true;
    }

    // Check exempt roles
    const exemptRoles = settings?.masking_rules?.exempt_roles || [];
    return exemptRoles.includes(user?.role);
  });

  // Check if masking feature is enabled for the account
  const isMaskingFeatureEnabled = computed(() => {
    return isCloudFeatureEnabled('data_masking');
  });

  // Check if masking is enabled for specific data types
  const isMaskingEnabled = computed(() => ({
    email:
      isMaskingFeatureEnabled.value &&
      shouldMaskData(currentUser.value, accountMaskingSettings.value, 'email'),
    phone:
      isMaskingFeatureEnabled.value &&
      shouldMaskData(currentUser.value, accountMaskingSettings.value, 'phone'),
  }));

  /**
   * Masks an email address if masking is enabled
   * @param {string} email - Email to mask
   * @param {Object} options - Masking options
   * @returns {string} Masked or original email
   */
  const maskEmail = (email, options = {}) => {
    if (!email || !isMaskingEnabled.value.email) {
      return email;
    }

    const pattern = getMaskingPattern(
      currentUser.value,
      accountMaskingSettings.value,
      'email'
    );
    return maskEmailUtil(email, { pattern, ...options });
  };

  /**
   * Masks a phone number if masking is enabled
   * @param {string} phone - Phone number to mask
   * @param {Object} options - Masking options
   * @returns {string} Masked or original phone number
   */
  const maskPhone = (phone, options = {}) => {
    if (!phone || !isMaskingEnabled.value.phone) {
      return phone;
    }

    const pattern = getMaskingPattern(
      currentUser.value,
      accountMaskingSettings.value,
      'phone'
    );
    return maskPhoneUtil(phone, { pattern, ...options });
  };

  /**
   * Masks a comma-separated list of email addresses
   * @param {string} emailList - Comma-separated emails
   * @param {Object} options - Masking options
   * @returns {string} Masked email list
   */
  const maskEmailListString = (emailList, options = {}) => {
    if (!emailList || !isMaskingEnabled.value.email) {
      return emailList;
    }

    const pattern = getMaskingPattern(
      currentUser.value,
      accountMaskingSettings.value,
      'email'
    );
    return maskEmailList(emailList, { pattern, ...options });
  };

  /**
   * Gets display value for email with masking consideration
   * @param {string} email - Original email
   * @param {Object} options - Display options
   * @returns {string} Display-ready email value
   */
  const getDisplayEmail = (email, options = {}) => {
    const { allowReveal = false, revealKey = null } = options;

    if (!email) return email;

    if (!isMaskingEnabled.value.email || canViewSensitiveData.value) {
      return email;
    }

    if (allowReveal && revealKey && revealStates.value.has(revealKey)) {
      const revealState = revealStates.value.get(revealKey);
      return revealState.getCurrentValue();
    }

    return maskEmail(email, options);
  };

  /**
   * Gets display value for phone with masking consideration
   * @param {string} phone - Original phone number
   * @param {Object} options - Display options
   * @returns {string} Display-ready phone value
   */
  const getDisplayPhone = (phone, options = {}) => {
    const { allowReveal = false, revealKey = null } = options;

    if (!phone) return phone;

    if (!isMaskingEnabled.value.phone || canViewSensitiveData.value) {
      return phone;
    }

    if (allowReveal && revealKey && revealStates.value.has(revealKey)) {
      const revealState = revealStates.value.get(revealKey);
      return revealState.getCurrentValue();
    }

    return maskPhone(phone, options);
  };

  /**
   * Creates a reveal handler for sensitive data
   * @param {string} originalValue - Original unmasked value
   * @param {string} dataType - 'email' or 'phone'
   * @param {string} revealKey - Unique key for this reveal state
   * @returns {Object} Reveal handler functions
   */
  const createReveal = (originalValue, dataType, revealKey) => {
    if (!originalValue || canViewSensitiveData.value) {
      return {
        reveal: () => originalValue,
        hide: () => originalValue,
        getCurrentValue: () => originalValue,
        isRevealed: true,
      };
    }

    const maskingFunction = dataType === 'email' ? maskEmail : maskPhone;
    const maskedValue = maskingFunction(originalValue);

    const revealHandler = createRevealHandler(originalValue, maskedValue);
    revealStates.value.set(revealKey, revealHandler);

    return {
      ...revealHandler,
      toggle: () => {
        const handler = revealStates.value.get(revealKey);
        return handler.isRevealed ? handler.hide() : handler.reveal();
      },
    };
  };

  /**
   * Determines if an email field should show a mailto link
   * @param {string} email - Email address
   * @returns {boolean} Whether to show mailto link
   */
  const shouldShowMailtoLink = email => {
    return !!(
      email &&
      (!isMaskingEnabled.value.email || canViewSensitiveData.value)
    );
  };

  /**
   * Determines if a phone field should show a tel link
   * @param {string} phone - Phone number
   * @returns {boolean} Whether to show tel link
   */
  const shouldShowTelLink = phone => {
    return !!(
      phone &&
      (!isMaskingEnabled.value.phone || canViewSensitiveData.value)
    );
  };

  /**
   * Gets the original value for use in links/copy operations
   * @param {string} value - The value (could be masked)
   * @param {string} originalValue - The original unmasked value
   * @returns {string} Value to use for links/copy
   */
  const getLinkValue = (value, originalValue) => {
    return canViewSensitiveData.value ||
      !accountMaskingSettings.value.masking_enabled
      ? originalValue
      : null;
  };

  /**
   * Checks if current user can reveal masked data
   * @returns {boolean} Whether user can reveal data
   */
  const canRevealData = computed(() => {
    // Users who can view sensitive data don't need reveal functionality
    if (canViewSensitiveData.value) {
      return false;
    }

    // Check if reveal is allowed in account settings
    return accountMaskingSettings.value?.masking_rules?.allow_reveal !== false;
  });

  /**
   * Logs access to sensitive data for audit purposes
   * @param {string} dataType - Type of data accessed
   * @param {string} action - Action performed ('view', 'reveal', 'copy')
   * @param {Object} context - Additional context
   */
  const logSensitiveDataAccess = () => {
    // const auditPayload = {
    //   dataType,
    //   action,
    //   context: {
    //     ...context,
    //     userId: currentUser.value?.id,
    //     accountId: currentAccount.value?.id,
    //     timestamp: new Date().toISOString(),
    //   },
    // };

    // Send audit log to backend
    try {
      // This would be implemented as an API call to log the audit event
      // fetch('/api/v1/audit_logs/masking', {
      //   method: 'POST',
      //   headers: { 'Content-Type': 'application/json' },
      //   body: JSON.stringify(auditPayload)
      // });
      if (process.env.NODE_ENV === 'development') {
        // eslint-disable-next-line no-console
        console.log('Audit log sent successfully');
      }
    } catch (error) {
      if (process.env.NODE_ENV === 'development') {
        // eslint-disable-next-line no-console
        console.error('Failed to log audit event:', error);
      }
    }
  };

  return {
    // Core masking functions
    maskEmail,
    maskPhone,
    maskEmailListString,

    // Display functions
    getDisplayEmail,
    getDisplayPhone,

    // Reveal functionality
    createReveal,
    canRevealData,

    // Link helpers
    shouldShowMailtoLink,
    shouldShowTelLink,
    getLinkValue,

    // State and permissions
    canViewSensitiveData,
    isMaskingEnabled,
    accountMaskingSettings,

    // Utility
    logSensitiveDataAccess,
  };
};
