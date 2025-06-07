import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import ContactDisplayService from '../helper/ContactDisplayService';

export function useContactDisplay() {
  const currentUser = useMapGetter('getCurrentUser');

  const isPiiMasked = computed(
    () => currentUser.value?.pii_masking_enabled || false
  );

  const getDisplayEmail = contact => {
    return ContactDisplayService.getDisplayEmail(contact, currentUser.value);
  };

  const getDisplayPhone = contact => {
    return ContactDisplayService.getDisplayPhone(contact, currentUser.value);
  };

  const getHybridContactId = contact => {
    return ContactDisplayService.getHybridContactId(contact);
  };

  const getChannelBasedLabel = inbox => {
    return ContactDisplayService.getChannelBasedLabel(inbox);
  };

  const shouldShowPiiData = () => {
    return ContactDisplayService.shouldShowPiiData(currentUser.value);
  };

  const getContactDisplayName = contact => {
    return ContactDisplayService.getContactDisplayName(
      contact,
      currentUser.value
    );
  };

  const getMaskedContactForDisplay = (contact, inbox = null) => {
    return ContactDisplayService.getMaskedContactForDisplay(
      contact,
      currentUser.value,
      inbox
    );
  };

  const shouldShowCopyButtons = () => {
    return !isPiiMasked.value;
  };

  const shouldShowEditButtons = () => {
    return !isPiiMasked.value;
  };

  const shouldAllowContactMerge = () => {
    return !isPiiMasked.value;
  };

  return {
    // State
    isPiiMasked,
    currentUser,

    // Display methods
    getDisplayEmail,
    getDisplayPhone,
    getHybridContactId,
    getChannelBasedLabel,
    getContactDisplayName,
    getMaskedContactForDisplay,

    // Permission checks
    shouldShowPiiData,
    shouldShowCopyButtons,
    shouldShowEditButtons,
    shouldAllowContactMerge,
  };
}

export default useContactDisplay;
