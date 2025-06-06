<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import FeatureToggle from 'dashboard/components/widgets/FeatureToggle.vue';

const { t } = useI18n();
const store = useStore();

const currentAccount = useMapGetter('getCurrentAccount');
// const uiFlags = useMapGetter('getUIFlags');

const isLoading = ref(false);

// Form data
const maskingSettings = ref({
  masking_enabled: true,
  masking_rules: {
    email: { enabled: true, pattern: 'standard' },
    phone: { enabled: true, pattern: 'standard' },
    admin_bypass: false, // Don't bypass for admins by default
    exempt_roles: [], // No roles exempt by default
    allow_reveal: true,
  },
});

const maskingPatterns = [
  { value: 'minimal', label: 'Minimal (show first character and domain)' },
  { value: 'standard', label: 'Standard (balanced privacy and usability)' },
  { value: 'complete', label: 'Complete (fully hidden)' },
];

const availableRoles = computed(() => [
  { value: 'administrator', label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR') },
  { value: 'agent', label: t('AGENT_MGMT.AGENT_TYPES.AGENT') },
]);

const isFormValid = computed(() => {
  return true; // Basic validation - can be enhanced
});

const loadSettings = () => {
  const accountSettings = currentAccount.value?.settings?.masking;
  if (accountSettings) {
    maskingSettings.value = {
      masking_enabled: accountSettings.masking_enabled !== false, // Default to true
      masking_rules: {
        ...maskingSettings.value.masking_rules,
        ...accountSettings.masking_rules,
      },
    };
  }
};

const updateSettings = async () => {
  if (!isFormValid.value) {
    useAlert(t('MASKING_SETTINGS.FORM.ERROR.VALIDATION'));
    return;
  }

  isLoading.value = true;

  try {
    const payload = {
      account: {
        settings: {
          ...currentAccount.value.settings,
          masking: maskingSettings.value,
        },
      },
    };

    await store.dispatch('accounts/update', payload);
    useAlert(t('MASKING_SETTINGS.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('MASKING_SETTINGS.UPDATE_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const toggleExemptRole = role => {
  const exemptRoles = maskingSettings.value.masking_rules.exempt_roles;
  const index = exemptRoles.indexOf(role);

  if (index > -1) {
    exemptRoles.splice(index, 1);
  } else {
    exemptRoles.push(role);
  }
};

const isRoleExempt = role => {
  return maskingSettings.value.masking_rules.exempt_roles.includes(role);
};

onMounted(() => {
  loadSettings();
});
</script>

<template>
  <FeatureToggle feature-key="data_masking">
    <SettingsLayout
      no-padding
      :breadcrumb-items="[
        {
          href: 'javascript:void(0)',
          label: $t('MASKING_SETTINGS.HEADER'),
        },
      ]"
    >
      <BaseSettingsHeader
        :title="$t('MASKING_SETTINGS.HEADER')"
        :description="$t('MASKING_SETTINGS.DESCRIPTION')"
        feature-name="masking"
      />

      <div class="wrapper">
        <form class="mx-0 flex-1" @submit.prevent="updateSettings">
          <!-- Enable Masking -->
          <div class="w-full">
            <label class="block">
              <input
                v-model="maskingSettings.masking_enabled"
                type="checkbox"
                class="mr-2"
              />
              {{ $t('MASKING_SETTINGS.FORM.ENABLE_MASKING.LABEL') }}
            </label>
            <p class="text-sm text-slate-600 mt-1 mb-4">
              {{ $t('MASKING_SETTINGS.FORM.ENABLE_MASKING.HELP_TEXT') }}
            </p>
          </div>

          <div v-if="maskingSettings.masking_enabled" class="space-y-6">
            <!-- Email Masking Settings -->
            <div class="w-full">
              <h3 class="text-lg font-medium mb-4">
                {{ $t('MASKING_SETTINGS.FORM.EMAIL_SECTION.TITLE') }}
              </h3>

              <div class="mb-4">
                <label class="block">
                  <input
                    v-model="maskingSettings.masking_rules.email.enabled"
                    type="checkbox"
                    class="mr-2"
                  />
                  {{ $t('MASKING_SETTINGS.FORM.EMAIL_SECTION.ENABLE_LABEL') }}
                </label>
              </div>

              <div
                v-if="maskingSettings.masking_rules.email.enabled"
                class="ml-6"
              >
                <label class="block">
                  {{ $t('MASKING_SETTINGS.FORM.EMAIL_SECTION.PATTERN_LABEL') }}
                  <select
                    v-model="maskingSettings.masking_rules.email.pattern"
                    class="mt-1 block w-full"
                  >
                    <option
                      v-for="pattern in maskingPatterns"
                      :key="pattern.value"
                      :value="pattern.value"
                    >
                      {{ pattern.label }}
                    </option>
                  </select>
                </label>
              </div>
            </div>

            <!-- Phone Masking Settings -->
            <div class="w-full">
              <h3 class="text-lg font-medium mb-4">
                {{ $t('MASKING_SETTINGS.FORM.PHONE_SECTION.TITLE') }}
              </h3>

              <div class="mb-4">
                <label class="block">
                  <input
                    v-model="maskingSettings.masking_rules.phone.enabled"
                    type="checkbox"
                    class="mr-2"
                  />
                  {{ $t('MASKING_SETTINGS.FORM.PHONE_SECTION.ENABLE_LABEL') }}
                </label>
              </div>

              <div
                v-if="maskingSettings.masking_rules.phone.enabled"
                class="ml-6"
              >
                <label class="block">
                  {{ $t('MASKING_SETTINGS.FORM.PHONE_SECTION.PATTERN_LABEL') }}
                  <select
                    v-model="maskingSettings.masking_rules.phone.pattern"
                    class="mt-1 block w-full"
                  >
                    <option
                      v-for="pattern in maskingPatterns"
                      :key="pattern.value"
                      :value="pattern.value"
                    >
                      {{ pattern.label }}
                    </option>
                  </select>
                </label>
              </div>
            </div>

            <!-- Permission Settings -->
            <div class="w-full">
              <h3 class="text-lg font-medium mb-4">
                {{ $t('MASKING_SETTINGS.FORM.PERMISSIONS_SECTION.TITLE') }}
              </h3>

              <div class="mb-4">
                <label class="block">
                  <input
                    v-model="maskingSettings.masking_rules.admin_bypass"
                    type="checkbox"
                    class="mr-2"
                  />
                  {{
                    $t(
                      'MASKING_SETTINGS.FORM.PERMISSIONS_SECTION.ADMIN_BYPASS_LABEL'
                    )
                  }}
                </label>
                <p class="text-sm text-slate-600 mt-1">
                  {{
                    $t(
                      'MASKING_SETTINGS.FORM.PERMISSIONS_SECTION.ADMIN_BYPASS_HELP'
                    )
                  }}
                </p>
                <p class="text-sm text-orange-600 mt-1">
                  {{
                    $t(
                      'MASKING_SETTINGS.FORM.PERMISSIONS_SECTION.ADMIN_BYPASS_NOTE'
                    )
                  }}
                </p>
              </div>

              <div class="mb-4">
                <label class="block mb-2">
                  {{
                    $t(
                      'MASKING_SETTINGS.FORM.PERMISSIONS_SECTION.EXEMPT_ROLES_LABEL'
                    )
                  }}
                </label>
                <div class="space-y-2">
                  <label
                    v-for="role in availableRoles"
                    :key="role.value"
                    class="flex items-center"
                  >
                    <input
                      :checked="isRoleExempt(role.value)"
                      type="checkbox"
                      class="mr-2"
                      @change="toggleExemptRole(role.value)"
                    />
                    {{ role.label }}
                  </label>
                </div>
                <p class="text-sm text-slate-600 mt-1">
                  {{
                    $t(
                      'MASKING_SETTINGS.FORM.PERMISSIONS_SECTION.EXEMPT_ROLES_HELP'
                    )
                  }}
                </p>
              </div>

              <div class="mb-4">
                <label class="block">
                  <input
                    v-model="maskingSettings.masking_rules.allow_reveal"
                    type="checkbox"
                    class="mr-2"
                  />
                  {{
                    $t(
                      'MASKING_SETTINGS.FORM.PERMISSIONS_SECTION.ALLOW_REVEAL_LABEL'
                    )
                  }}
                </label>
                <p class="text-sm text-slate-600 mt-1">
                  {{
                    $t(
                      'MASKING_SETTINGS.FORM.PERMISSIONS_SECTION.ALLOW_REVEAL_HELP'
                    )
                  }}
                </p>
              </div>
            </div>

            <!-- Preview Section -->
            <div class="w-full bg-slate-50 p-4 rounded-lg">
              <h3 class="text-lg font-medium mb-4">
                {{ $t('MASKING_SETTINGS.FORM.PREVIEW_SECTION.TITLE') }}
              </h3>

              <div class="space-y-2 text-sm">
                <div>
                  <span class="font-medium">
                    {{
                      $t('MASKING_SETTINGS.FORM.PREVIEW_SECTION.EMAIL_EXAMPLE')
                    }}
                  </span>
                  <span class="ml-2 font-mono">
                    {{
                      $t('MASKING_SETTINGS.FORM.PREVIEW_SECTION.EMAIL_ARROW')
                    }}
                    {{
                      maskingSettings.masking_rules.email.pattern === 'minimal'
                        ? $t(
                            'MASKING_SETTINGS.FORM.PREVIEW_SECTION.EMAIL_MINIMAL'
                          )
                        : maskingSettings.masking_rules.email.pattern ===
                            'standard'
                          ? 'j***e@e***.com'
                          : '*** HIDDEN ***'
                    }}
                  </span>
                </div>
                <div>
                  <span class="font-medium">
                    {{
                      $t('MASKING_SETTINGS.FORM.PREVIEW_SECTION.PHONE_EXAMPLE')
                    }}
                  </span>
                  <span class="ml-2 font-mono">
                    {{
                      $t('MASKING_SETTINGS.FORM.PREVIEW_SECTION.PHONE_ARROW')
                    }}
                    {{
                      maskingSettings.masking_rules.phone.pattern === 'minimal'
                        ? $t(
                            'MASKING_SETTINGS.FORM.PREVIEW_SECTION.PHONE_MINIMAL'
                          )
                        : maskingSettings.masking_rules.phone.pattern ===
                            'standard'
                          ? '***-***-4567'
                          : '*** HIDDEN ***'
                    }}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- Submit Button -->
          <div class="flex items-center justify-end mt-8">
            <Button
              type="submit"
              :disabled="!isFormValid"
              :is-loading="isLoading"
            >
              {{ $t('MASKING_SETTINGS.FORM.SUBMIT') }}
            </Button>
          </div>
        </form>
      </div>
    </SettingsLayout>
  </FeatureToggle>
</template>

<style lang="scss" scoped>
.wrapper {
  padding: var(--space-large) var(--space-larger);
  width: 100%;
  max-width: 720px;
}

label {
  @apply font-medium text-slate-800 dark:text-slate-200;
}

input[type='checkbox'] {
  @apply rounded border-slate-300 text-woot-600 focus:border-woot-300 focus:ring focus:ring-offset-0 focus:ring-woot-200 focus:ring-opacity-50;
}

select {
  @apply rounded-md border-slate-300 shadow-sm focus:border-woot-300 focus:ring focus:ring-woot-200 focus:ring-opacity-50;
}
</style>
