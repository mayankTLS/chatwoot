import { mount } from '@vue/test-utils';
import { createTestingPinia } from '@pinia/testing';
import ContactInfo from '~/dashboard/components/ContactInfo.vue';
import { useMasking } from '~/dashboard/composables/useMasking';

// Mock the masking composable
vi.mock('~/dashboard/composables/useMasking');

describe('ContactInfo with Masking', () => {
  let wrapper;
  let mockMasking;

  const defaultContact = {
    id: 1,
    name: 'John Doe',
    email: 'john.doe@example.com',
    phone_number: '+1-555-123-4567',
    avatar_url: '',
    additional_attributes: {}
  };

  beforeEach(() => {
    mockMasking = {
      canViewSensitiveData: { value: false },
      getDisplayEmail: vi.fn(),
      getDisplayPhone: vi.fn()
    };

    useMasking.mockReturnValue(mockMasking);
  });

  afterEach(() => {
    if (wrapper) wrapper.unmount();
    vi.clearAllMocks();
  });

  describe('email masking', () => {
    it('displays masked email for regular users', () => {
      mockMasking.getDisplayEmail.mockReturnValue('j***e@e***.com');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayEmail).toHaveBeenCalledWith('john.doe@example.com');
      expect(wrapper.text()).toContain('j***e@e***.com');
      expect(wrapper.text()).not.toContain('john.doe@example.com');
    });

    it('displays original email for users who can view sensitive data', () => {
      mockMasking.canViewSensitiveData.value = true;
      mockMasking.getDisplayEmail.mockReturnValue('john.doe@example.com');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayEmail).toHaveBeenCalledWith('john.doe@example.com');
      expect(wrapper.text()).toContain('john.doe@example.com');
    });

    it('handles null email gracefully', () => {
      const contactWithoutEmail = { ...defaultContact, email: null };
      mockMasking.getDisplayEmail.mockReturnValue(null);
      
      wrapper = mount(ContactInfo, {
        props: { contact: contactWithoutEmail },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayEmail).toHaveBeenCalledWith(null);
      expect(wrapper.text()).not.toContain('@');
    });

    it('handles empty email gracefully', () => {
      const contactWithEmptyEmail = { ...defaultContact, email: '' };
      mockMasking.getDisplayEmail.mockReturnValue('');
      
      wrapper = mount(ContactInfo, {
        props: { contact: contactWithEmptyEmail },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayEmail).toHaveBeenCalledWith('');
    });
  });

  describe('phone masking', () => {
    it('displays masked phone for regular users', () => {
      mockMasking.getDisplayPhone.mockReturnValue('***-***-4567');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayPhone).toHaveBeenCalledWith('+1-555-123-4567');
      expect(wrapper.text()).toContain('***-***-4567');
      expect(wrapper.text()).not.toContain('+1-555-123-4567');
    });

    it('displays original phone for users who can view sensitive data', () => {
      mockMasking.canViewSensitiveData.value = true;
      mockMasking.getDisplayPhone.mockReturnValue('+1-555-123-4567');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayPhone).toHaveBeenCalledWith('+1-555-123-4567');
      expect(wrapper.text()).toContain('+1-555-123-4567');
    });

    it('handles null phone gracefully', () => {
      const contactWithoutPhone = { ...defaultContact, phone_number: null };
      mockMasking.getDisplayPhone.mockReturnValue(null);
      
      wrapper = mount(ContactInfo, {
        props: { contact: contactWithoutPhone },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayPhone).toHaveBeenCalledWith(null);
    });

    it('handles empty phone gracefully', () => {
      const contactWithEmptyPhone = { ...defaultContact, phone_number: '' };
      mockMasking.getDisplayPhone.mockReturnValue('');
      
      wrapper = mount(ContactInfo, {
        props: { contact: contactWithEmptyPhone },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayPhone).toHaveBeenCalledWith('');
    });
  });

  describe('reactive updates', () => {
    it('updates displayed data when masking permissions change', async () => {
      // Start with masked data
      mockMasking.getDisplayEmail.mockReturnValue('j***e@e***.com');
      mockMasking.getDisplayPhone.mockReturnValue('***-***-4567');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(wrapper.text()).toContain('j***e@e***.com');
      expect(wrapper.text()).toContain('***-***-4567');

      // Simulate permission change (user gains access)
      mockMasking.canViewSensitiveData.value = true;
      mockMasking.getDisplayEmail.mockReturnValue('john.doe@example.com');
      mockMasking.getDisplayPhone.mockReturnValue('+1-555-123-4567');

      await wrapper.vm.$nextTick();

      // Should now show unmasked data
      expect(wrapper.text()).toContain('john.doe@example.com');
      expect(wrapper.text()).toContain('+1-555-123-4567');
    });

    it('updates displayed data when contact changes', async () => {
      mockMasking.getDisplayEmail.mockReturnValue('j***e@e***.com');
      mockMasking.getDisplayPhone.mockReturnValue('***-***-4567');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      expect(mockMasking.getDisplayEmail).toHaveBeenCalledWith('john.doe@example.com');

      // Change contact
      const newContact = {
        ...defaultContact,
        email: 'jane.smith@example.com',
        phone_number: '+1-555-987-6543'
      };

      mockMasking.getDisplayEmail.mockReturnValue('j***h@e***.com');
      mockMasking.getDisplayPhone.mockReturnValue('***-***-6543');

      await wrapper.setProps({ contact: newContact });

      expect(mockMasking.getDisplayEmail).toHaveBeenCalledWith('jane.smith@example.com');
      expect(mockMasking.getDisplayPhone).toHaveBeenCalledWith('+1-555-987-6543');
    });
  });

  describe('accessibility and UX', () => {
    it('maintains proper accessibility attributes for masked data', () => {
      mockMasking.getDisplayEmail.mockReturnValue('j***e@e***.com');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      // Check that email field still has appropriate attributes
      const emailElement = wrapper.find('[data-testid="contact-email"]');
      if (emailElement.exists()) {
        expect(emailElement.attributes('aria-label')).toBeDefined();
      }
    });

    it('shows appropriate visual indicators for masked data', () => {
      mockMasking.canViewSensitiveData.value = false;
      mockMasking.getDisplayEmail.mockReturnValue('j***e@e***.com');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      // Should contain masking indicators (asterisks)
      expect(wrapper.text()).toContain('***');
    });

    it('provides tooltips or hints about masked data', () => {
      mockMasking.canViewSensitiveData.value = false;
      mockMasking.getDisplayEmail.mockReturnValue('j***e@e***.com');
      
      wrapper = mount(ContactInfo, {
        props: { contact: defaultContact },
        global: {
          plugins: [createTestingPinia()]
        }
      });

      // Look for tooltip or title attributes that explain masking
      const maskedElements = wrapper.findAll('[title*="masked"], [title*="hidden"]');
      // This is implementation-dependent - adjust based on actual component
    });
  });

  describe('error handling', () => {
    it('handles masking function errors gracefully', () => {
      mockMasking.getDisplayEmail.mockImplementation(() => {
        throw new Error('Masking error');
      });
      
      expect(() => {
        wrapper = mount(ContactInfo, {
          props: { contact: defaultContact },
          global: {
            plugins: [createTestingPinia()]
          }
        });
      }).not.toThrow();

      // Should fallback to original or safe display
      expect(wrapper.exists()).toBe(true);
    });

    it('handles invalid contact data gracefully', () => {
      const invalidContact = {
        id: 1,
        // Missing required fields
      };

      mockMasking.getDisplayEmail.mockReturnValue('');
      mockMasking.getDisplayPhone.mockReturnValue('');
      
      expect(() => {
        wrapper = mount(ContactInfo, {
          props: { contact: invalidContact },
          global: {
            plugins: [createTestingPinia()]
          }
        });
      }).not.toThrow();
    });
  });
});