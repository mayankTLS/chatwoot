/**
 * Utility functions for masking sensitive data like email addresses and phone numbers
 */

/**
 * Masks an email address while preserving domain visibility
 * @param {string} email - The email address to mask
 * @param {Object} options - Masking options
 * @param {string} options.pattern - Masking pattern ('minimal', 'standard', 'complete')
 * @param {boolean} options.preserveDomain - Whether to show the domain
 * @returns {string} Masked email address
 */
export const maskEmail = (email, options = {}) => {
  if (!email || typeof email !== 'string') {
    return email;
  }

  const { pattern = 'standard', preserveDomain = true } = options;

  // Handle invalid email format
  if (!email.includes('@')) {
    return pattern === 'complete' ? '*** HIDDEN ***' : email;
  }

  const [localPart, domain] = email.split('@');
  
  switch (pattern) {
    case 'minimal':
      // Show first character of local part and full domain
      return `${localPart.charAt(0)}***@${preserveDomain ? domain : '***'}`;
    
    case 'standard':
      // Show first and last character of local part, mask domain partially
      if (localPart.length <= 2) {
        return `***@${preserveDomain ? domain : '***'}`;
      }
      const maskedLocal = `${localPart.charAt(0)}***${localPart.charAt(localPart.length - 1)}`;
      const maskedDomain = preserveDomain ? domain : `***${domain.split('.').pop()}`;
      return `${maskedLocal}@${maskedDomain}`;
    
    case 'complete':
      return '*** HIDDEN ***';
    
    default:
      return `***@${preserveDomain ? domain : '***'}`;
  }
};

/**
 * Masks a phone number while preserving country code and last few digits
 * @param {string} phone - The phone number to mask
 * @param {Object} options - Masking options
 * @param {string} options.pattern - Masking pattern ('minimal', 'standard', 'complete')
 * @param {boolean} options.preserveCountryCode - Whether to show the country code
 * @param {number} options.visibleDigits - Number of digits to show at the end
 * @returns {string} Masked phone number
 */
export const maskPhone = (phone, options = {}) => {
  if (!phone || typeof phone !== 'string') {
    return phone;
  }

  const { 
    pattern = 'standard', 
    preserveCountryCode = true, 
    visibleDigits = 4 
  } = options;

  // Remove all non-digit characters for processing
  const digitsOnly = phone.replace(/\D/g, '');
  
  if (digitsOnly.length === 0) {
    return phone;
  }

  switch (pattern) {
    case 'minimal':
      // Show country code and last 4 digits
      if (digitsOnly.length <= 4) {
        return '***';
      }
      const countryCode = digitsOnly.startsWith('1') ? '+1' : '+**';
      const lastDigits = digitsOnly.slice(-visibleDigits);
      return preserveCountryCode 
        ? `${countryCode} ***-***-${lastDigits}`
        : `***-***-${lastDigits}`;
    
    case 'standard':
      // Show country code and last few digits with format preservation
      if (digitsOnly.length <= visibleDigits) {
        return '***';
      }
      const last = digitsOnly.slice(-visibleDigits);
      const masked = '*'.repeat(digitsOnly.length - visibleDigits);
      
      // Try to preserve original formatting structure
      if (phone.includes('+')) {
        const cc = preserveCountryCode ? phone.substring(0, phone.indexOf(' ') || 3) : '+**';
        return `${cc} ${masked.slice(0, 3)}-${masked.slice(3, 6)}-${last}`;
      }
      return `${masked}-${last}`;
    
    case 'complete':
      return '*** HIDDEN ***';
    
    default:
      const defaultLast = digitsOnly.slice(-visibleDigits);
      return `***-***-${defaultLast}`;
  }
};

/**
 * Determines if sensitive data should be masked for the current user
 * @param {Object} currentUser - Current user object
 * @param {Object} accountSettings - Account masking settings
 * @param {string} dataType - Type of data ('email' or 'phone')
 * @returns {boolean} Whether data should be masked
 */
export const shouldMaskData = (currentUser, accountSettings, dataType = 'email') => {
  // Default to masking enabled if not explicitly configured
  const maskingEnabled = accountSettings?.masking_enabled !== false;
  
  // No masking if explicitly disabled at account level
  if (!maskingEnabled) {
    return false;
  }

  // Admin users can bypass masking only if explicitly enabled
  if (currentUser?.type === 'administrator' && accountSettings?.masking_rules?.admin_bypass === true) {
    return false;
  }

  // Check role-based permissions
  const exemptRoles = accountSettings?.masking_rules?.exempt_roles || [];
  if (exemptRoles.includes(currentUser?.role)) {
    return false;
  }

  // Check data type specific settings
  const dataTypeSettings = accountSettings?.masking_rules?.[dataType];
  return dataTypeSettings?.enabled !== false;
};

/**
 * Gets the appropriate masking pattern for a user and data type
 * @param {Object} currentUser - Current user object
 * @param {Object} accountSettings - Account masking settings
 * @param {string} dataType - Type of data ('email' or 'phone')
 * @returns {string} Masking pattern to use
 */
export const getMaskingPattern = (currentUser, accountSettings, dataType = 'email') => {
  const dataTypeSettings = accountSettings?.masking_rules?.[dataType];
  
  // Return user-specific pattern if available
  if (currentUser?.masking_preferences?.[dataType]) {
    return currentUser.masking_preferences[dataType];
  }
  
  // Return account default pattern
  return dataTypeSettings?.pattern || 'standard';
};

/**
 * Masks multiple email addresses in a comma-separated string
 * @param {string} emailString - Comma-separated email addresses
 * @param {Object} options - Masking options
 * @returns {string} Comma-separated masked email addresses
 */
export const maskEmailList = (emailString, options = {}) => {
  if (!emailString || typeof emailString !== 'string') {
    return emailString;
  }

  return emailString
    .split(',')
    .map(email => maskEmail(email.trim(), options))
    .join(', ');
};

/**
 * Creates a reveal function for temporarily showing unmasked data
 * @param {string} originalValue - The original unmasked value
 * @param {string} maskedValue - The masked value
 * @param {number} revealDuration - How long to show original value (ms)
 * @returns {Object} Object with reveal state and toggle function
 */
export const createRevealHandler = (originalValue, maskedValue, revealDuration = 3000) => {
  let isRevealed = false;
  let timeoutId = null;

  const reveal = () => {
    isRevealed = true;
    
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
    
    timeoutId = setTimeout(() => {
      isRevealed = false;
    }, revealDuration);
    
    return originalValue;
  };

  const hide = () => {
    isRevealed = false;
    if (timeoutId) {
      clearTimeout(timeoutId);
    }
    return maskedValue;
  };

  const getCurrentValue = () => isRevealed ? originalValue : maskedValue;

  return {
    reveal,
    hide,
    getCurrentValue,
    get isRevealed() { return isRevealed; }
  };
};