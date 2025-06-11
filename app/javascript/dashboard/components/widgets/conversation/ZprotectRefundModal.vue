<script setup>
import { ref, computed, nextTick } from 'vue';
import Modal from 'dashboard/components/Modal.vue';
import ZprotectAPI from '../../../api/integrations/zprotect';

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'success']);

// const { t } = useI18n(); // Disabled for now as we use $t in template

const loading = ref(false);
const error = ref('');

// Form state
const formData = ref({
  restock: true,
  note: '',
  selectedItems: {},
});

// Initialize selected items with available quantities
const initializeSelectedItems = () => {
  const selected = {};
  props.order.lineItems?.forEach(item => {
    if (item.availableQuantity > 0) {
      selected[item.id] = {
        selected: false,
        quantity: 1,
        maxQuantity: item.availableQuantity,
      };
    }
  });
  // Force reactivity by completely replacing the object
  formData.value.selectedItems = { ...selected };
};

initializeSelectedItems();

// Computed properties
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

const refundableItems = computed(() => {
  return (
    props.order.lineItems?.filter(item => item.availableQuantity > 0) || []
  );
});

const selectedRefundItems = computed(() => {
  return refundableItems.value.filter(
    item => formData.value.selectedItems[item.id]?.selected
  );
});

const totalRefundAmount = computed(() => {
  return selectedRefundItems.value.reduce((total, item) => {
    const quantity = formData.value.selectedItems[item.id]?.quantity || 0;
    const price = parseFloat(item.price) || 0;
    return total + price * quantity;
  }, 0);
});

const hasSelectedItems = computed(() => {
  // Explicitly depend on formData to ensure reactivity
  const items = formData.value.selectedItems;
  return Object.values(items).some(item => item?.selected);
});

const canSubmit = computed(() => {
  // More explicit dependency tracking
  const hasItems = hasSelectedItems.value;
  const isNotLoading = !loading.value;
  return hasItems && isNotLoading;
});

// Methods
const toggleItemSelection = async item => {
  const selected = formData.value.selectedItems[item.id];
  if (selected) {
    selected.selected = !selected.selected;
    // Reset quantity to 1 when selecting
    if (selected.selected) {
      selected.quantity = 1;
    }

    // Force reactivity by reassigning the entire object
    formData.value.selectedItems = { ...formData.value.selectedItems };

    // Ensure DOM updates
    await nextTick();
  }
};

const updateQuantity = (item, quantity) => {
  const selected = formData.value.selectedItems[item.id];
  if (selected) {
    const maxQty = selected.maxQuantity;
    selected.quantity = Math.max(1, Math.min(quantity, maxQty));
  }
};

const selectAllItems = () => {
  refundableItems.value.forEach(item => {
    const selected = formData.value.selectedItems[item.id];
    if (selected) {
      selected.selected = true;
      selected.quantity = 1;
    }
  });
};

const deselectAllItems = () => {
  Object.values(formData.value.selectedItems).forEach(selected => {
    selected.selected = false;
  });
};

// Actions
const handleRefund = async () => {
  try {
    loading.value = true;
    error.value = '';

    // Validate storeId for multi-store operations
    if (props.order.isMultiStore && !props.order.storeId) {
      throw new Error(
        'Store ID is missing for this order. Cannot perform multi-store operation.'
      );
    }

    // Build refund items array
    const refundItems = selectedRefundItems.value.map(item => ({
      lineItemId: item.id,
      quantity: formData.value.selectedItems[item.id].quantity,
    }));

    const options = {
      note: formData.value.note.trim(),
      restock: formData.value.restock,
      storeId: props.order.storeId, // for multi-store support
    };

    const result = await ZprotectAPI.refundOrder(
      props.order.id,
      refundItems,
      options
    );

    if (result.data.success) {
      emit('success', {
        type: 'refund',
        order: props.order,
        refundItems: refundItems,
        result: result.data,
      });
    } else {
      error.value = result.data.error || 'Failed to process refund';
    }
  } catch (e) {
    // Enhanced error handling with specific messages
    if (e.response?.status === 404) {
      error.value =
        'Refund order endpoint not found. Please check configuration.';
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
        e.response?.data?.error ||
        'Failed to process refund. Please try again.';
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
  <Modal show :on-close="handleClose" size="large">
    <div class="w-full max-w-2xl mx-auto">
      <!-- Header -->
      <div
        class="flex items-center justify-between p-4 border-b border-slate-200 dark:border-slate-700"
      >
        <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
          {{ $t('ZPROTECT.REFUND_MODAL.TITLE') }}
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
      <div class="p-4 space-y-4 max-h-96 overflow-y-auto">
        <!-- Order Details -->
        <div class="bg-slate-50 dark:bg-slate-800 p-3 rounded-lg">
          <div class="flex justify-between items-start">
            <div>
              <div class="font-medium text-slate-900 dark:text-slate-100 mb-1">
                {{ $t('ZPROTECT.ORDER_ITEM.ORDER_NUMBER')
                }}{{ $t('ZPROTECT.ORDER_ITEM.ORDER_PREFIX')
                }}{{ displayOrderNumber }}
              </div>
              <div class="text-sm text-slate-600 dark:text-slate-400">
                {{
                  $t('ZPROTECT.REFUND_MODAL.REFUNDABLE_ITEMS', {
                    count: refundableItems.length,
                  })
                }}
              </div>
            </div>
            <div class="text-right">
              <div class="text-sm text-slate-600 dark:text-slate-400">
                {{ $t('ZPROTECT.REFUND_MODAL.SELECTED_TOTAL') }}
              </div>
              <div
                class="font-medium text-lg text-slate-900 dark:text-slate-100"
              >
                {{ formatCurrency(totalRefundAmount, order.currency) }}
              </div>
            </div>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="flex justify-between items-center">
          <div class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ $t('ZPROTECT.REFUND_MODAL.SELECT_ITEMS') }}
          </div>
          <div class="space-x-2">
            <button
              :disabled="loading"
              class="text-sm text-blue-600 hover:text-blue-800 disabled:opacity-50"
              @click="selectAllItems"
            >
              {{ $t('GENERAL.SELECT_ALL') }}
            </button>
            <button
              :disabled="loading"
              class="text-sm text-slate-600 hover:text-slate-800 disabled:opacity-50"
              @click="deselectAllItems"
            >
              {{ $t('GENERAL.CLEAR_ALL') }}
            </button>
          </div>
        </div>

        <!-- Refundable Items List -->
        <div
          class="space-y-2 border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden"
        >
          <div
            v-for="item in refundableItems"
            :key="item.id"
            class="p-3 border-b border-slate-200 dark:border-slate-700 last:border-b-0"
            :class="{
              'bg-blue-50 dark:bg-blue-900/20':
                formData.selectedItems[item.id]?.selected,
            }"
          >
            <div class="flex items-start space-x-3">
              <!-- Checkbox -->
              <input
                type="checkbox"
                :checked="formData.selectedItems[item.id]?.selected"
                :disabled="loading"
                class="mt-1 h-4 w-4 text-blue-600 focus:ring-blue-500 border-slate-300 rounded"
                @change="toggleItemSelection(item)"
              />

              <!-- Item Details -->
              <div class="flex-1 min-w-0">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="font-medium text-slate-900 dark:text-slate-100">
                      {{ item.title }}
                    </div>
                    <div
                      v-if="item.variantTitle"
                      class="text-sm text-slate-600 dark:text-slate-400"
                    >
                      {{ item.variantTitle }}
                    </div>
                    <div
                      class="text-sm text-slate-600 dark:text-slate-400 mt-1"
                    >
                      <span>
                        {{ formatCurrency(item.price, order.currency) }}
                        {{ $t('ZPROTECT.ORDER_ITEM.EACH') }}
                      </span>
                      <span class="mx-2">{{
                        $t('ZPROTECT.REFUND_MODAL.SEPARATOR')
                      }}</span>
                      <span>
                        {{ item.availableQuantity }}
                        {{ $t('ZPROTECT.REFUND_MODAL.AVAILABLE_FOR_REFUND') }}
                      </span>
                    </div>
                  </div>

                  <!-- Quantity Input -->
                  <div
                    v-if="formData.selectedItems[item.id]?.selected"
                    class="flex items-center space-x-2 ml-4"
                  >
                    <label class="text-sm text-slate-600 dark:text-slate-400">{{
                      $t('ZPROTECT.REFUND_MODAL.QUANTITY_LABEL')
                    }}</label>
                    <input
                      type="number"
                      :value="formData.selectedItems[item.id]?.quantity"
                      :min="1"
                      :max="formData.selectedItems[item.id]?.maxQuantity"
                      :disabled="loading"
                      class="w-16 px-2 py-1 text-sm border border-slate-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100"
                      @input="
                        updateQuantity(item, parseInt($event.target.value))
                      "
                    />
                  </div>
                </div>

                <!-- Line Total -->
                <div
                  v-if="formData.selectedItems[item.id]?.selected"
                  class="mt-2 text-right text-sm font-medium text-slate-900 dark:text-slate-100"
                >
                  {{ $t('ZPROTECT.REFUND_MODAL.LINE_TOTAL')
                  }}{{ $t('ZPROTECT.ORDER_ITEM.SEPARATOR') }}
                  {{
                    formatCurrency(
                      parseFloat(item.price) *
                        (formData.selectedItems[item.id]?.quantity || 0),
                      order.currency
                    )
                  }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- No refundable items -->
        <div
          v-if="refundableItems.length === 0"
          class="text-center py-8 text-slate-500"
        >
          <svg
            class="w-12 h-12 mx-auto mb-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <div class="text-lg font-medium">
            {{ $t('ZPROTECT.REFUND_MODAL.NO_ITEMS.TITLE') }}
          </div>
          <div class="text-sm">
            {{ $t('ZPROTECT.REFUND_MODAL.NO_ITEMS.MESSAGE') }}
          </div>
        </div>

        <!-- Form Options -->
        <div class="space-y-4">
          <!-- Restock Option -->
          <label class="flex items-center">
            <input
              v-model="formData.restock"
              type="checkbox"
              :disabled="loading"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-slate-300 rounded"
            />
            <span class="ml-2 text-sm text-slate-700 dark:text-slate-300">
              {{ $t('ZPROTECT.REFUND_MODAL.RESTOCK_LABEL') }}
            </span>
          </label>

          <!-- Refund Note -->
          <div>
            <label
              class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2"
            >
              {{ $t('ZPROTECT.REFUND_MODAL.REFUND_NOTE_LABEL') }}
            </label>
            <textarea
              v-model="formData.note"
              :disabled="loading"
              rows="2"
              :placeholder="$t('ZPROTECT.REFUND_MODAL.REFUND_NOTE_PLACEHOLDER')"
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
        class="flex justify-between items-center p-4 border-t border-slate-200 dark:border-slate-700"
      >
        <!-- Summary -->
        <div
          v-if="hasSelectedItems"
          class="text-sm text-slate-600 dark:text-slate-400"
        >
          {{
            $t('ZPROTECT.REFUND_MODAL.ITEMS_SELECTED', {
              count: selectedRefundItems.length,
            })
          }}
        </div>
        <div v-else class="text-sm text-slate-400">
          {{ $t('ZPROTECT.REFUND_MODAL.NO_ITEMS_SELECTED') }}
        </div>

        <!-- Action Buttons -->
        <div class="flex space-x-3">
          <button
            :disabled="loading"
            type="button"
            class="px-4 py-2 text-sm font-medium text-slate-700 bg-white border border-slate-300 rounded-md hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-600 dark:hover:bg-slate-700"
            @click="handleClose"
          >
            {{ $t('ZPROTECT.REFUND_MODAL.CANCEL_BUTTON') }}
          </button>
          <button
            :disabled="!canSubmit"
            type="button"
            class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 flex items-center"
            @click="handleRefund"
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
                ? $t('ZPROTECT.REFUND_MODAL.LOADING_BUTTON')
                : `${$t('ZPROTECT.REFUND_MODAL.CONFIRM_BUTTON')} (${formatCurrency(totalRefundAmount, order.currency)})`
            }}
          </button>
        </div>
      </div>
    </div>
  </Modal>
</template>

<style scoped>
/* Any specific styles if needed */
</style>
