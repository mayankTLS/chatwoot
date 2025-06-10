<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import ZprotectAPI from '../../../api/integrations/zprotect';

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'success']);

const loading = ref(false);
const error = ref('');

// Form state
const formData = ref({
  refund: true,
  restock: true,
  reason: 'OTHER',
  staffNote: '',
});

const { t } = useI18n();

const cancellationReasons = computed(() => [
  { value: 'CUSTOMER', label: t('ZPROTECT.REASONS.CUSTOMER') },
  { value: 'INVENTORY', label: t('ZPROTECT.REASONS.INVENTORY') },
  { value: 'FRAUD', label: t('ZPROTECT.REASONS.FRAUD') },
  { value: 'OTHER', label: t('ZPROTECT.REASONS.OTHER') },
]);

// Computed properties
const orderTotal = computed(() => {
  return parseFloat(props.order?.totalPrice || 0);
});

const formatCurrency = (amount, currency) => {
  return new Intl.NumberFormat('en', {
    style: 'currency',
    currency: currency || 'USD',
  }).format(amount);
};

const displayOrderNumber = computed(() => {
  return (
    props.order?.orderNumber ||
    props.order?.order_number ||
    props.order?.name?.replace('#', '') ||
    props.order?.id?.toString().split('/').pop()
  );
});

// Actions
const handleCancel = async () => {
  try {
    loading.value = true;
    error.value = '';

    // Validate storeId for multi-store operations
    if (props.order.isMultiStore && !props.order.storeId) {
      throw new Error(
        'Store ID is missing for this order. Cannot perform multi-store operation.'
      );
    }

    const options = {
      refund: formData.value.refund,
      restock: formData.value.restock,
      reason: formData.value.reason,
      staffNote: formData.value.staffNote.trim(),
      storeId: props.order.storeId, // for multi-store support
    };

    const result = await ZprotectAPI.cancelOrder(props.order.id, options);

    if (result.data.success) {
      emit('success', {
        type: 'cancel',
        order: props.order,
        result: result.data,
      });
    } else {
      error.value = result.data.error || 'Failed to cancel order';
    }
  } catch (e) {
    // Enhanced error handling with specific messages
    if (e.response?.status === 404) {
      error.value =
        'Cancel order endpoint not found. Please check configuration.';
    } else if (
      e.response?.status === 500 ||
      e.response?.status === 502 ||
      e.response?.status === 503
    ) {
      error.value =
        'Service temporarily unavailable. Please try again in a few moments.';
    } else if (e.response?.status === 429) {
      error.value =
        'Too many requests. Please wait a moment before trying again.';
    } else if (e.message && e.message.includes('Store ID is missing')) {
      error.value = e.message;
    } else {
      error.value =
        e.response?.data?.error || 'Failed to cancel order. Please try again.';
    }
  } finally {
    loading.value = false;
  }
};

const handleClose = () => {
  if (!loading.value) {
    emit('close');
  }
};
</script>

<template>
  <Modal show :on-close="handleClose" size="medium">
    <div class="w-full max-w-md mx-auto">
      <!-- Header -->
      <div
        class="flex items-center justify-between p-4 border-b border-slate-200 dark:border-slate-700"
      >
        <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
          {{ $t('ZPROTECT.CANCEL_MODAL.TITLE') }}
        </h3>
        <button
          :disabled="loading"
          class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
          @click="handleClose"
        >
          <svg
            class="w-6 h-6"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      <!-- Content -->
      <div class="p-4 space-y-4">
        <!-- Order Details -->
        <div class="bg-slate-50 dark:bg-slate-800 p-3 rounded-lg">
          <div class="text-sm">
            <div class="font-medium text-slate-900 dark:text-slate-100 mb-1">
              {{ $t('ZPROTECT.ORDER_ITEM.ORDER_NUMBER')
              }}{{ $t('ZPROTECT.ORDER_ITEM.ORDER_PREFIX')
              }}{{ displayOrderNumber }}
            </div>
            <div class="text-slate-600 dark:text-slate-400 mb-2">
              {{ $t('ZPROTECT.ORDER_ITEM.TOTAL')
              }}{{ $t('ZPROTECT.ORDER_ITEM.SEPARATOR') }}
              {{ formatCurrency(orderTotal, order.currency) }}
            </div>
            <div class="flex flex-wrap gap-2">
              <span
                class="px-2 py-1 text-xs font-medium rounded-full bg-blue-100 text-blue-800"
              >
                {{ order.financialStatus || order.financial_status }}
              </span>
              <span
                class="px-2 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800"
              >
                {{ order.fulfillmentStatus || order.fulfillment_status }}
              </span>
            </div>
          </div>
        </div>

        <!-- Warning Message -->
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
          <div class="flex">
            <svg
              class="w-5 h-5 text-yellow-400 mr-2 mt-0.5 flex-shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z"
              />
            </svg>
            <div class="text-sm text-yellow-800">
              <div class="font-medium">
                {{ $t('ZPROTECT.CANCEL_MODAL.WARNING.TITLE') }}
              </div>
              <div class="mt-1">
                {{ $t('ZPROTECT.CANCEL_MODAL.WARNING.MESSAGE') }}
              </div>
            </div>
          </div>
        </div>

        <!-- Form Fields -->
        <div class="space-y-4">
          <!-- Cancellation Reason -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              {{ $t('ZPROTECT.CANCEL_MODAL.REASON_LABEL') }}
            </label>
            <select
              v-model="formData.reason"
              :disabled="loading"
              class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100"
            >
              <option
                v-for="reason in cancellationReasons"
                :key="reason.value"
                :value="reason.value"
              >
                {{ reason.label }}
              </option>
            </select>
          </div>

          <!-- Checkboxes -->
          <div class="space-y-3">
            <label class="flex items-center">
              <input
                v-model="formData.refund"
                type="checkbox"
                :disabled="loading"
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-slate-300 rounded"
              />
              <span class="ml-2 text-sm text-slate-700 dark:text-slate-300">
                {{ $t('ZPROTECT.CANCEL_MODAL.REFUND_LABEL') }}
              </span>
            </label>

            <label class="flex items-center">
              <input
                v-model="formData.restock"
                type="checkbox"
                :disabled="loading"
                class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-slate-300 rounded"
              />
              <span class="ml-2 text-sm text-slate-700 dark:text-slate-300">
                {{ $t('ZPROTECT.CANCEL_MODAL.RESTOCK_LABEL') }}
              </span>
            </label>
          </div>

          <!-- Staff Note -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              {{ $t('ZPROTECT.CANCEL_MODAL.STAFF_NOTE_LABEL') }}
            </label>
            <textarea
              v-model="formData.staffNote"
              :disabled="loading"
              rows="3"
              :placeholder="$t('ZPROTECT.CANCEL_MODAL.STAFF_NOTE_PLACEHOLDER')"
              class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100 resize-none"
            />
          </div>
        </div>

        <!-- Error Message -->
        <div
          v-if="error"
          class="bg-red-50 border border-red-200 rounded-lg p-3"
        >
          <div class="flex">
            <svg
              class="w-5 h-5 text-red-400 mr-2 flex-shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
            <div class="text-sm text-red-800">{{ error }}</div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div
        class="flex justify-end space-x-3 p-4 border-t border-slate-200 dark:border-slate-700"
      >
        <button
          :disabled="loading"
          type="button"
          class="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-md hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-600 dark:hover:bg-slate-700"
          @click="handleClose"
        >
          {{ $t('ZPROTECT.CANCEL_MODAL.CANCEL_BUTTON') }}
        </button>
        <button
          :disabled="loading"
          type="button"
          class="px-4 py-2 text-sm font-medium text-white bg-red-600 border border-transparent rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 disabled:opacity-50 flex items-center"
          @click="handleCancel"
        >
          <svg
            v-if="loading"
            class="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              class="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              stroke-width="4"
            />
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
          {{
            loading
              ? $t('ZPROTECT.CANCEL_MODAL.LOADING_BUTTON')
              : $t('ZPROTECT.CANCEL_MODAL.CONFIRM_BUTTON')
          }}
        </button>
      </div>
    </div>
  </Modal>
</template>

<style scoped>
/* Any specific styles if needed */
</style>
