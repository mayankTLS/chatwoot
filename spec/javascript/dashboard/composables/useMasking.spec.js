import { mount } from '@vue/test-utils';
import { createTestingPinia } from '@pinia/testing';
import { useMasking } from '~/dashboard/composables/useMasking';
import { useAccount } from '~/dashboard/composables/store/useAccount';
import { useAuth } from '~/dashboard/composables/store/useAuth';

// Mock the stores
vi.mock('~/dashboard/composables/store/useAccount');
vi.mock('~/dashboard/composables/store/useAuth');

describe('useMasking', () => {
  let mockAccount;
  let mockUser;
  let mockAccountStore;
  let mockAuthStore;

  beforeEach(() => {
    mockAccount = {
      id: 1,
      settings: {
        masking: {
          masking_enabled: true,
          masking_rules: {
            admin_bypass: false,  // Don't bypass for admins by default
            allow_reveal: false,
            exempt_roles: [],
            email: { enabled: true, pattern: 'standard' },
            phone: { enabled: true, pattern: 'standard' }
          }
        }
      }
    };

    mockUser = {
      id: 1,
      role: 'agent',
      type: 'user'
    };

    mockAccountStore = {
      getAccount: vi.fn(() => mockAccount)
    };

    mockAuthStore = {
      getCurrentUser: vi.fn(() => mockUser)
    };

    useAccount.mockReturnValue(mockAccountStore);
    useAuth.mockReturnValue(mockAuthStore);
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('canViewSensitiveData', () => {
    it('returns true when masking is disabled', () => {
      mockAccount.settings.masking.masking_enabled = false;
      const { canViewSensitiveData } = useMasking();
      expect(canViewSensitiveData.value).toBe(true);
    });

    it('returns false for admin without bypass (default)', () => {
      mockUser.type = 'administrator';
      const { canViewSensitiveData } = useMasking();
      expect(canViewSensitiveData.value).toBe(false);
    });

    it('returns true for admin with bypass explicitly enabled', () => {
      mockUser.type = 'administrator';
      mockAccount.settings.masking.masking_rules.admin_bypass = true;
      const { canViewSensitiveData } = useMasking();
      expect(canViewSensitiveData.value).toBe(true);
    });

    it('returns true for exempt roles', () => {
      mockAccount.settings.masking.masking_rules.exempt_roles = ['agent'];
      const { canViewSensitiveData } = useMasking();
      expect(canViewSensitiveData.value).toBe(true);
    });

    it('returns false for regular users when masking is enabled', () => {
      const { canViewSensitiveData } = useMasking();
      expect(canViewSensitiveData.value).toBe(false);
    });

    it('handles missing masking configuration gracefully', () => {
      mockAccount.settings = {};
      const { canViewSensitiveData } = useMasking();
      expect(canViewSensitiveData.value).toBe(true);
    });
  });

  describe('getDisplayEmail', () => {
    it('returns original email when user can view sensitive data', () => {
      mockUser.type = 'administrator';
      const { getDisplayEmail } = useMasking();
      const result = getDisplayEmail('john.doe@example.com');
      expect(result).toBe('john.doe@example.com');
    });

    it('masks email with standard pattern for regular users', () => {
      const { getDisplayEmail } = useMasking();
      const result = getDisplayEmail('john.doe@example.com');
      expect(result).toBe('j***e@e***.com');
    });

    it('masks email with minimal pattern', () => {
      mockAccount.settings.masking.masking_rules.email.pattern = 'minimal';
      const { getDisplayEmail } = useMasking();
      const result = getDisplayEmail('john.doe@example.com');
      expect(result).toBe('j***@example.com');
    });

    it('completely hides email with complete pattern', () => {
      mockAccount.settings.masking.masking_rules.email.pattern = 'complete';
      const { getDisplayEmail } = useMasking();
      const result = getDisplayEmail('john.doe@example.com');
      expect(result).toBe('*** HIDDEN ***');
    });

    it('returns original value for invalid emails', () => {
      const { getDisplayEmail } = useMasking();
      const result = getDisplayEmail('invalid-email');
      expect(result).toBe('invalid-email');
    });

    it('handles null and undefined values', () => {
      const { getDisplayEmail } = useMasking();
      expect(getDisplayEmail(null)).toBeNull();
      expect(getDisplayEmail(undefined)).toBeUndefined();
      expect(getDisplayEmail('')).toBe('');
    });

    it('returns original when email masking is disabled', () => {
      mockAccount.settings.masking.masking_rules.email.enabled = false;
      const { getDisplayEmail } = useMasking();
      const result = getDisplayEmail('john.doe@example.com');
      expect(result).toBe('john.doe@example.com');
    });
  });

  describe('getDisplayPhone', () => {
    it('returns original phone when user can view sensitive data', () => {
      mockUser.type = 'administrator';
      const { getDisplayPhone } = useMasking();
      const result = getDisplayPhone('+1-555-123-4567');
      expect(result).toBe('+1-555-123-4567');
    });

    it('masks phone with standard pattern for regular users', () => {
      const { getDisplayPhone } = useMasking();
      const result = getDisplayPhone('555-123-4567');
      expect(result).toBe('***-***-4567');
    });

    it('masks phone with minimal pattern', () => {
      mockAccount.settings.masking.masking_rules.phone.pattern = 'minimal';
      const { getDisplayPhone } = useMasking();
      const result = getDisplayPhone('+1-555-123-4567');
      expect(result).toBe('+1 ***-***-4567');
    });

    it('completely hides phone with complete pattern', () => {
      mockAccount.settings.masking.masking_rules.phone.pattern = 'complete';
      const { getDisplayPhone } = useMasking();
      const result = getDisplayPhone('+1-555-123-4567');
      expect(result).toBe('*** HIDDEN ***');
    });

    it('handles short phone numbers', () => {
      const { getDisplayPhone } = useMasking();
      const result = getDisplayPhone('1234');
      expect(result).toBe('***');
    });

    it('handles null and undefined values', () => {
      const { getDisplayPhone } = useMasking();
      expect(getDisplayPhone(null)).toBeNull();
      expect(getDisplayPhone(undefined)).toBeUndefined();
      expect(getDisplayPhone('')).toBe('');
    });

    it('returns original when phone masking is disabled', () => {
      mockAccount.settings.masking.masking_rules.phone.enabled = false;
      const { getDisplayPhone } = useMasking();
      const result = getDisplayPhone('+1-555-123-4567');
      expect(result).toBe('+1-555-123-4567');
    });

    it('returns original for non-numeric values', () => {
      const { getDisplayPhone } = useMasking();
      const result = getDisplayPhone('not-a-phone');
      expect(result).toBe('not-a-phone');
    });
  });

  describe('reactive updates', () => {
    it('updates masking when account settings change', async () => {
      const { canViewSensitiveData, getDisplayEmail } = useMasking();
      
      // Initially should mask
      expect(canViewSensitiveData.value).toBe(false);
      expect(getDisplayEmail('test@example.com')).toBe('t***t@e***.com');
      
      // Disable masking
      mockAccount.settings.masking.masking_enabled = false;
      mockAccountStore.getAccount.mockReturnValue(mockAccount);
      
      // Should update reactively
      await nextTick();
      expect(canViewSensitiveData.value).toBe(true);
      expect(getDisplayEmail('test@example.com')).toBe('test@example.com');
    });

    it('updates masking when user role changes', async () => {
      const { canViewSensitiveData } = useMasking();
      
      // Initially should mask for agent
      expect(canViewSensitiveData.value).toBe(false);
      
      // Change to admin
      mockUser.type = 'administrator';
      mockAuthStore.getCurrentUser.mockReturnValue(mockUser);
      
      // Should update reactively
      await nextTick();
      expect(canViewSensitiveData.value).toBe(true);
    });
  });

  describe('edge cases', () => {
    it('handles missing account gracefully', () => {
      mockAccountStore.getAccount.mockReturnValue(null);
      const { canViewSensitiveData, getDisplayEmail } = useMasking();
      
      expect(canViewSensitiveData.value).toBe(true);
      expect(getDisplayEmail('test@example.com')).toBe('test@example.com');
    });

    it('handles missing user gracefully', () => {
      mockAuthStore.getCurrentUser.mockReturnValue(null);
      const { canViewSensitiveData, getDisplayEmail } = useMasking();
      
      expect(canViewSensitiveData.value).toBe(true);
      expect(getDisplayEmail('test@example.com')).toBe('test@example.com');
    });

    it('handles malformed masking configuration', () => {
      mockAccount.settings.masking = { invalid: 'config' };
      const { canViewSensitiveData } = useMasking();
      
      expect(canViewSensitiveData.value).toBe(true);
    });

    it('uses fallback pattern for invalid patterns', () => {
      mockAccount.settings.masking.masking_rules.email.pattern = 'invalid';
      const { getDisplayEmail } = useMasking();
      const result = getDisplayEmail('test@example.com');
      
      // Should fallback to standard pattern
      expect(result).toBe('t***t@e***.com');
    });
  });
});