class ContactDisplayService {
  static getDisplayEmail(contact, currentUser) {
    if (currentUser?.pii_masking_enabled) {
      return '[PROTECTED]';
    }
    return contact?.email || '';
  }

  static getDisplayPhone(contact, currentUser) {
    if (currentUser?.pii_masking_enabled) {
      return '[PROTECTED]';
    }
    return contact?.phone_number || '';
  }

  static getHybridContactId(contact) {
    if (!contact) return '';

    // Primary: "John D. #1234"
    if (contact.name && contact.name.trim()) {
      const namesParts = contact.name.trim().split(' ');
      let initials;

      if (namesParts.length === 1) {
        // Single name like "John"
        initials = namesParts[0].charAt(0).toUpperCase();
      } else {
        // Multiple names - take first letter of each
        initials = namesParts
          .map(name => name.charAt(0).toUpperCase())
          .join('. ');
      }

      return `${initials} #${contact.id}`;
    }

    // Fallback: "CONT-2024-1234"
    const year = new Date().getFullYear();
    return `CONT-${year}-${contact.id}`;
  }

  static getChannelBasedLabel(inbox) {
    if (!inbox?.channel_type) return 'Contact';

    const channel = inbox.channel_type;
    switch (channel) {
      case 'Channel::WebWidget':
        return 'Website Visitor';
      case 'Channel::Email':
        return 'Email Contact';
      case 'Channel::Api':
        return 'API Contact';
      case 'Channel::FacebookPage':
        return 'Facebook Contact';
      case 'Channel::TwitterProfile':
        return 'Twitter Contact';
      case 'Channel::TwilioSms':
      case 'Channel::Sms':
        return 'SMS Contact';
      case 'Channel::Whatsapp':
        return 'WhatsApp Contact';
      case 'Channel::Line':
        return 'LINE Contact';
      case 'Channel::Telegram':
        return 'Telegram Contact';
      default:
        return 'Contact';
    }
  }

  static shouldShowPiiData(currentUser) {
    return !currentUser?.pii_masking_enabled;
  }

  static getContactDisplayName(contact, currentUser) {
    if (!contact) return '';

    // If PII is masked and no name, use hybrid ID
    if (currentUser?.pii_masking_enabled && !contact.name) {
      return this.getHybridContactId(contact);
    }

    // Use name if available, otherwise hybrid ID
    return contact.name || this.getHybridContactId(contact);
  }

  static getMaskedContactForDisplay(contact, currentUser, inbox = null) {
    if (!contact) return null;

    if (!currentUser?.pii_masking_enabled) {
      return contact;
    }

    return {
      ...contact,
      email: this.getDisplayEmail(contact, currentUser),
      phone_number: this.getDisplayPhone(contact, currentUser),
      display_name: this.getContactDisplayName(contact, currentUser),
      hybrid_id: this.getHybridContactId(contact),
      channel_label: this.getChannelBasedLabel(inbox),
    };
  }
}

export default ContactDisplayService;
