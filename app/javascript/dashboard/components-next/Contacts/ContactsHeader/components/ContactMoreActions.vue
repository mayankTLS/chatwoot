<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { usePiiProtectedActions } from 'dashboard/composables/usePiiProtectedActions';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const emit = defineEmits(['add', 'import']);

const { t } = useI18n();
const { canCreateContacts } = usePiiProtectedActions();

const contactMenuItems = computed(() => [
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.ADD_CONTACT'),
    action: 'add',
    value: 'add',
    icon: 'i-lucide-plus',
    disabled: !canCreateContacts.value,
  },
  {
    label: t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.IMPORT_CONTACT'),
    action: 'import',
    value: 'import',
    icon: 'i-lucide-download',
    disabled: !canCreateContacts.value,
  },
]);
const showActionsDropdown = ref(false);

const handleContactAction = ({ action, disabled }) => {
  if (disabled) return;

  if (action === 'add') {
    emit('add');
  } else if (action === 'import') {
    emit('import');
  }
};
</script>

<template>
  <div v-on-clickaway="() => (showActionsDropdown = false)" class="relative">
    <Button
      icon="i-lucide-ellipsis-vertical"
      color="slate"
      variant="ghost"
      size="sm"
      :class="showActionsDropdown ? 'bg-n-alpha-2' : ''"
      @click="showActionsDropdown = !showActionsDropdown"
    />
    <DropdownMenu
      v-if="showActionsDropdown"
      :menu-items="contactMenuItems"
      class="ltr:right-0 rtl:left-0 mt-1 w-52 top-full"
      @action="handleContactAction($event)"
    />
  </div>
</template>
