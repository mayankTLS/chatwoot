<script setup>
/* eslint-disable no-console */
import { ref, watch, computed, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useFunctionGetter } from 'dashboard/composables/store';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ZprotectAPI from '../../../api/integrations/zprotect';
import ZprotectOrderItem from './ZprotectOrderItem.vue';
import ZprotectCancelModal from './ZprotectCancelModal.vue';
import ZprotectRefundModal from './ZprotectRefundModal.vue';

const props = defineProps({
  contactId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

const contact = useFunctionGetter('contacts/getContact', props.contactId);

const hasSearchableInfo = computed(() => {
  const hasInfo = !!contact.value?.email || !!contact.value?.phone_number;
  console.log('Contact info check:', {
    contactId: props.contactId,
    contact: contact.value,
    email: contact.value?.email,
    phone: contact.value?.phone_number,
    hasInfo,
  });

  // For debugging: temporarily bypass the check if we have a contact ID
  // This will attempt the API call even without email/phone
  if (!hasInfo && props.contactId) {
    console.log(
      'No contact info but contact ID exists, allowing API call anyway for debugging'
    );
    return true;
  }

  return hasInfo;
});

const orders = ref([]);
const loading = ref(true);
const error = ref('');
const isMultiStore = ref(false);
const storeStatuses = ref({});
const summary = ref({});

// Modal states
const showCancelModal = ref(false);
const showRefundModal = ref(false);
const selectedOrder = ref(null);

const fetchOrders = async () => {
  try {
    console.log('Fetching ZProtect orders for contact:', props.contactId);
    loading.value = true;
    error.value = '';

    const response = await ZprotectAPI.getOrders(props.contactId);
    console.log('ZProtect API response:', response);
    const data = response.data;
    console.log('Response data:', data);

    if (data.success) {
      orders.value = data.orders || [];
      isMultiStore.value = !!data.multiStore;
      storeStatuses.value = data.storeStatuses || {};
      summary.value = data.summary || {};
      console.log('Orders loaded:', orders.value.length);
    } else {
      error.value = data.error || 'Failed to fetch orders';
      orders.value = [];
      console.log('API returned error:', error.value);
    }
  } catch (e) {
    error.value =
      e.response?.data?.error || 'Failed to connect to order service';
    orders.value = [];
    console.log('Exception in fetchOrders:', e);
  } finally {
    loading.value = false;
  }
};

const refreshOrders = async () => {
  await fetchOrders();
};

// Group orders by store for multi-store display
const ordersByStore = computed(() => {
  if (!isMultiStore.value) {
    return { 'Main Store': orders.value };
  }

  const grouped = {};
  orders.value.forEach(order => {
    const storeName = order.storeName || 'Main Store';
    if (!grouped[storeName]) {
      grouped[storeName] = [];
    }
    grouped[storeName].push(order);
  });

  return grouped;
});

// Handle order actions
const handleCancelOrder = order => {
  selectedOrder.value = order;
  showCancelModal.value = true;
};

const handleRefundOrder = order => {
  selectedOrder.value = order;
  showRefundModal.value = true;
};

const handleOrderAction = async () => {
  // Refresh orders after any action
  await nextTick();
  await refreshOrders();

  // Close modals
  showCancelModal.value = false;
  showRefundModal.value = false;
  selectedOrder.value = null;
};

// Store status helpers
const getStoreStatusIcon = storeName => {
  const status = storeStatuses.value[storeName];
  switch (status) {
    case 'success':
      return '✅';
    case 'failed':
      return '⚠️';
    default:
      return '🔄';
  }
};

const getStoreStatusClass = storeName => {
  const status = storeStatuses.value[storeName];
  switch (status) {
    case 'success':
      return 'text-green-600';
    case 'failed':
      return 'text-red-600';
    default:
      return 'text-yellow-600';
  }
};

// Check if store has priority orders (paid but unfulfilled)
const hasStoreHighPriority = storeOrders => {
  return storeOrders.some(
    order =>
      order.financialStatus === 'paid' &&
      order.fulfillmentStatus !== 'fulfilled'
  );
};

// Watch for contact ID changes
watch(
  () => props.contactId,
  () => {
    console.log(
      'Contact ID changed:',
      props.contactId,
      'hasSearchableInfo:',
      hasSearchableInfo.value
    );
    if (hasSearchableInfo.value) {
      fetchOrders();
    } else {
      console.log('No searchable contact info, skipping order fetch');
    }
  },
  { immediate: true }
);

// Also watch for contact data changes (in case contact loads after component mounts)
watch(
  () => contact.value,
  newContact => {
    console.log('Contact data changed:', newContact);
    if (newContact && hasSearchableInfo.value) {
      console.log('Contact loaded with searchable info, fetching orders');
      fetchOrders();
    }
  }
);
</script>

<template>
  <div class="px-4 py-2 text-slate-700 dark:text-slate-200">
    <!-- Header with refresh button -->
    <div class="flex items-center justify-between mb-3">
      <h4 class="text-sm font-medium">
        {{ t('CONVERSATION.ZPROTECT.ORDERS_LIST.TITLE') }}
      </h4>
      <button
        :disabled="loading"
        class="p-1 text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 disabled:opacity-50"
        :title="t('CONVERSATION.ZPROTECT.ORDERS_LIST.REFRESH_BUTTON')"
        @click="refreshOrders"
      >
        <svg
          class="w-4 h-4"
          :class="{ 'animate-spin': loading }"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
          />
        </svg>
      </button>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="flex items-center justify-center py-8">
      <Spinner size="sm" />
      <span class="ml-2 text-sm text-slate-500">{{
        t('CONVERSATION.ZPROTECT.ORDERS_LIST.LOADING')
      }}</span>
    </div>

    <!-- Error state -->
    <div v-else-if="error" class="text-red-600 text-sm py-4">
      <div class="flex items-center">
        <svg
          class="w-4 h-4 mr-2"
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
        {{ error }}
      </div>
    </div>

    <!-- No contact info -->
    <div v-else-if="!hasSearchableInfo" class="text-slate-500 text-sm py-4">
      <div class="flex items-center">
        <svg
          class="w-4 h-4 mr-2"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        {{ t('CONVERSATION.ZPROTECT.ORDERS_LIST.NO_CONTACT_INFO') }}
      </div>
    </div>

    <!-- Orders content -->
    <div v-else-if="orders.length === 0" class="text-slate-500 text-sm py-4">
      <div class="flex items-center">
        <svg
          class="w-4 h-4 mr-2"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"
          />
        </svg>
        {{ t('CONVERSATION.ZPROTECT.ORDERS_LIST.NO_ORDERS') }}
      </div>
    </div>

    <!-- Multi-store summary -->
    <div
      v-else-if="isMultiStore && summary.totalStores"
      class="mb-4 p-3 bg-slate-50 dark:bg-slate-800 rounded-lg"
    >
      <div class="text-sm">
        <div class="font-medium mb-1">
          {{
            t('CONVERSATION.ZPROTECT.ORDERS_LIST.ORDERS_SUMMARY', {
              orderCount: orders.length,
              storeCount: summary.totalStores,
            })
          }}
        </div>
        <div class="text-slate-600 dark:text-slate-400 text-xs">
          {{
            t('CONVERSATION.ZPROTECT.ORDERS_LIST.STORE_STATUS', {
              successful: summary.successfulStores,
              failed: summary.failedStores || 0,
            })
          }}
        </div>
      </div>
    </div>

    <!-- Orders by store -->
    <div v-else class="space-y-4">
      <div
        v-for="(storeOrders, storeName) in ordersByStore"
        :key="storeName"
        class="border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden"
      >
        <!-- Store header (for multi-store) -->
        <div
          v-if="isMultiStore"
          class="px-3 py-2 bg-slate-50 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700"
          :class="{
            'bg-red-50 dark:bg-red-900/20': hasStoreHighPriority(storeOrders),
          }"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <span class="mr-2" :class="getStoreStatusClass(storeName)">
                {{ getStoreStatusIcon(storeName) }}
              </span>
              <span class="font-medium text-sm">{{ storeName }}</span>
              <span
                v-if="hasStoreHighPriority(storeOrders)"
                class="ml-2 px-2 py-1 bg-red-100 text-red-800 text-xs rounded-full"
              >
                {{ t('CONVERSATION.ZPROTECT.ORDERS_LIST.PRIORITY_ORDERS') }}
              </span>
            </div>
            <span class="text-xs text-slate-500">
              {{
                t('CONVERSATION.ZPROTECT.ORDERS_LIST.ORDER_COUNT', {
                  count: storeOrders.length,
                })
              }}
            </span>
          </div>
        </div>

        <!-- Orders list -->
        <div class="divide-y divide-slate-200 dark:divide-slate-700">
          <ZprotectOrderItem
            v-for="order in storeOrders"
            :key="order.id"
            :order="order"
            @cancel="handleCancelOrder"
            @refund="handleRefundOrder"
          />
        </div>
      </div>
    </div>

    <!-- Cancel Order Modal -->
    <ZprotectCancelModal
      v-if="showCancelModal"
      :order="selectedOrder"
      @close="showCancelModal = false"
      @success="handleOrderAction"
    />

    <!-- Refund Order Modal -->
    <ZprotectRefundModal
      v-if="showRefundModal"
      :order="selectedOrder"
      @close="showRefundModal = false"
      @success="handleOrderAction"
    />
  </div>
</template>

<style scoped>
/* Custom styles if needed */
</style>
