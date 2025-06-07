import camelcaseKeys from 'camelcase-keys';
import ContactDisplayService from '../../../helper/ContactDisplayService';

export const getters = {
  getContacts($state) {
    return $state.sortOrder.map(contactId => $state.records[contactId]);
  },
  getContactsList($state) {
    const contacts = $state.sortOrder.map(
      contactId => $state.records[contactId]
    );
    return camelcaseKeys(contacts, { deep: true });
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
  getContact: $state => id => {
    const contact = $state.records[id];
    return contact || {};
  },
  getContactById: $state => id => {
    const contact = $state.records[id];
    return camelcaseKeys(contact || {}, {
      deep: true,
      stopPaths: ['custom_attributes'],
    });
  },
  getMeta: $state => {
    return $state.meta;
  },
  getAppliedContactFilters: _state => {
    return _state.appliedFilters;
  },
  getAppliedContactFiltersV4: _state => {
    return _state.appliedFilters.map(camelcaseKeys);
  },

  // PII Masking Display Getters
  getContactDisplayEmail: ($state, contactGetters, rootState) => contactId => {
    const contact = contactGetters.getContact(contactId);
    const currentUser = rootState.auth.currentUser;
    return ContactDisplayService.getDisplayEmail(contact, currentUser);
  },

  getContactDisplayPhone: ($state, contactGetters, rootState) => contactId => {
    const contact = contactGetters.getContact(contactId);
    const currentUser = rootState.auth.currentUser;
    return ContactDisplayService.getDisplayPhone(contact, currentUser);
  },

  getContactHybridId: ($state, contactGetters) => contactId => {
    const contact = contactGetters.getContact(contactId);
    return ContactDisplayService.getHybridContactId(contact);
  },

  getContactDisplayName: ($state, contactGetters, rootState) => contactId => {
    const contact = contactGetters.getContact(contactId);
    const currentUser = rootState.auth.currentUser;
    return ContactDisplayService.getContactDisplayName(contact, currentUser);
  },

  getMaskedContactForDisplay:
    ($state, contactGetters, rootState) => (contactId, inboxId) => {
      const contact = contactGetters.getContact(contactId);
      const currentUser = rootState.auth.currentUser;
      const inbox = rootState.inboxes.records.find(i => i.id === inboxId);
      return ContactDisplayService.getMaskedContactForDisplay(
        contact,
        currentUser,
        inbox
      );
    },

  getContactChannelLabel: ($state, contactGetters, rootState) => inboxId => {
    const inbox = rootState.inboxes.records.find(i => i.id === inboxId);
    return ContactDisplayService.getChannelBasedLabel(inbox);
  },

  shouldShowContactPii: ($state, contactGetters, rootState) => {
    const currentUser = rootState.auth.currentUser;
    return ContactDisplayService.shouldShowPiiData(currentUser);
  },
};
