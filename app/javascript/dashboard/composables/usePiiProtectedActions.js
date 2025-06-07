import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

export function usePiiProtectedActions() {
  const currentUser = useMapGetter('getCurrentUser');

  const isPiiMasked = computed(
    () => currentUser.value?.pii_masking_enabled || false
  );

  const canEditContacts = computed(() => !isPiiMasked.value);
  const canCreateContacts = computed(() => !isPiiMasked.value);
  const canViewPii = computed(() => !isPiiMasked.value);
  const canExportContacts = computed(() => !isPiiMasked.value);
  const canMergeContacts = computed(() => !isPiiMasked.value);
  const canBulkEditContacts = computed(() => !isPiiMasked.value);

  const getPiiProtectionMessage = () => {
    return 'Contact information is protected for your role.';
  };

  const getActionBlockedMessage = action => {
    return `${action} is not available due to PII protection settings`;
  };

  return {
    isPiiMasked,
    canEditContacts,
    canCreateContacts,
    canViewPii,
    canExportContacts,
    canMergeContacts,
    canBulkEditContacts,
    getPiiProtectionMessage,
    getActionBlockedMessage,
  };
}
