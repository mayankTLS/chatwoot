<script setup>
import { ref, watch, computed, nextTick } from 'vue';
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

const contact = useFunctionGetter('contacts/getContact', props.contactId);

const hasSearchableInfo = computed(() => {
  return !!contact.value?.email || !!contact.value?.phone_number;
});

const orders = ref([]);
const loading = ref(true);
const error = ref('');
const isMultiStore = ref(false);
const storeStatuses = ref({});
const summary = ref({});
const selectedStore = ref(null);
const expandedStores = ref({});

// Modal states
const showCancelModal = ref(false);
const showRefundModal = ref(false);
const selectedOrder = ref(null);

const fetchOrders = async () => {
  try {
    loading.value = true;
    error.value = '';

    const response = await ZprotectAPI.getOrders(props.contactId);
    const data = response.data;

    if (data.success) {
      orders.value = data.orders || [];
      isMultiStore.value = !!data.multiStore;
      storeStatuses.value = data.storeStatuses || {};
      summary.value = data.summary || {};
    } else {
      error.value = data.error || 'Failed to fetch orders';
      orders.value = [];
    }
  } catch (e) {
    error.value =
      e.response?.data?.error || 'Failed to connect to order service';
    orders.value = [];
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

// Get store list for left panel
const storeList = computed(() => {
  const stores = Object.keys(ordersByStore.value)
    .map(storeName => {
      const storeOrders = ordersByStore.value[storeName];
      // Find the most recent order date for this store
      const mostRecentOrderDate = storeOrders.reduce((latest, order) => {
        const orderDate = new Date(order.createdAt || order.created_at);
        return orderDate > latest ? orderDate : latest;
      }, new Date(0));

      return {
        name: storeName,
        orderCount: storeOrders.length,
        status: storeStatuses.value[storeName] || 'success',
        orders: storeOrders,
        hasOpenOrders: hasStoreOpenOrders(storeOrders),
        mostRecentOrderDate,
      };
    })
    .filter(store => store.orderCount > 0) // Only show stores with orders
    .sort((a, b) => b.mostRecentOrderDate - a.mostRecentOrderDate); // Sort by most recent order first

  return stores;
});

// Get orders for selected store
const selectedStoreOrders = computed(() => {
  if (!selectedStore.value) return [];
  return ordersByStore.value[selectedStore.value] || [];
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

// Check if store has open orders (paid but unfulfilled or pending)
const hasStoreOpenOrders = storeOrders => {
  return storeOrders.some(order => {
    const financial = order.financialStatus?.toLowerCase();
    const fulfillment = order.fulfillmentStatus?.toLowerCase();

    // Open orders are: paid but unfulfilled, or pending/authorized
    return (
      (financial === 'paid' && fulfillment !== 'fulfilled') ||
      financial === 'pending' ||
      financial === 'authorized'
    );
  });
};

// Toggle store expansion
const toggleStore = storeName => {
  if (selectedStore.value === storeName) {
    selectedStore.value = null;
  } else {
    selectedStore.value = storeName;
  }
};

// Get store status styling
const getStoreRowClass = store => {
  const baseClass =
    'p-3 border mb-2 rounded-lg cursor-pointer transition-colors';

  if (selectedStore.value === store.name) {
    // Selected store styling - red highlighting only for stores with open orders
    if (store.hasOpenOrders) {
      return `${baseClass} bg-red-100 border-red-300`;
    }
    return `${baseClass} bg-gray-100 border-gray-300`;
  }

  // Non-selected store styling - red highlighting only for stores with open orders
  if (store.hasOpenOrders) {
    return `${baseClass} bg-red-50 border-red-200 hover:bg-red-100`;
  }
  return `${baseClass} border-gray-200 hover:bg-gray-50`;
};

// Watch for contact ID changes
watch(
  () => props.contactId,
  () => {
    if (hasSearchableInfo.value) {
      fetchOrders();
    }
  },
  { immediate: true }
);

// Also watch for contact data changes (in case contact loads after component mounts)
watch(
  () => contact.value,
  newContact => {
    if (newContact && hasSearchableInfo.value) {
      fetchOrders();
    }
  }
);

// Auto-select first store if only one store with orders
watch(
  () => storeList.value,
  newStores => {
    if (newStores.length === 1 && !selectedStore.value) {
      selectedStore.value = newStores[0].name;
    }
    // If current selected store no longer has orders, clear selection
    else if (
      selectedStore.value &&
      !newStores.find(store => store.name === selectedStore.value)
    ) {
      selectedStore.value = null;
    }
  }
);
</script>

<template>
  <div class="px-4 py-2 text-slate-700 dark:text-slate-200">
    <!-- Header with refresh button -->
    <div class="flex items-center justify-between mb-3">
      <h4 class="text-sm font-medium">
        {{ $t('CONVERSATION.ZPROTECT.ORDERS_LIST.TITLE') }}
      </h4>
      <button
        :disabled="loading"
        class="p-1 text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 disabled:opacity-50"
        :title="$t('CONVERSATION.ZPROTECT.ORDERS_LIST.REFRESH_BUTTON')"
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
        $t('CONVERSATION.ZPROTECT.ORDERS_LIST.LOADING')
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
        {{ $t('CONVERSATION.ZPROTECT.ORDERS_LIST.NO_CONTACT_INFO') }}
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
        {{ $t('CONVERSATION.ZPROTECT.ORDERS_LIST.NO_ORDERS') }}
      </div>
    </div>

    <!-- Orders content -->
    <div v-else>
      <!-- Summary -->
      <div
        v-if="isMultiStore && summary.totalStores"
        class="mb-4 p-3 bg-blue-50 rounded-lg flex items-center"
      >
        <svg
          class="w-4 h-4 mr-2 text-blue-600"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path
            d="M9 11H7v8h2v-8zm4 0h-2v8h2v-8zm4 0h-2v8h2v-8zm2-7H3v2h2v13a2 2 0 002 2h10a2 2 0 002-2V6h2V4z"
          />
        </svg>
        <span class="text-sm font-medium text-slate-700">
          {{
            $t('CONVERSATION.ZPROTECT.ORDERS_LIST.ORDERS_SUMMARY', {
              orderCount: orders.length,
              storeCount: summary.totalStores,
            })
          }}
        </span>
      </div>

      <!-- Two column layout -->
      <div class="flex flex-col lg:flex-row gap-4" style="min-height: 400px">
        <!-- Left: Store List -->
        <div class="w-full lg:w-80 overflow-y-auto">
          <div class="space-y-2">
            <div
              v-for="store in storeList"
              :key="store.name"
              :class="getStoreRowClass(store)"
              @click="toggleStore(store.name)"
            >
              <div class="flex items-center">
                <span class="mr-3" :class="getStoreStatusClass(store.name)">
                  {{ getStoreStatusIcon(store.name) }}
                </span>
                <div class="flex-1">
                  <div class="flex items-center">
                    <span class="text-sm font-medium text-slate-700">{{
                      store.name
                    }}</span>
                    <span class="ml-2 text-xs text-slate-500">
                      ({{ store.orderCount }} orders)
                    </span>
                  </div>
                </div>
                <svg
                  class="w-4 h-4 text-slate-400 transition-transform"
                  :class="{ 'rotate-90': selectedStore === store.name }"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 5l7 7-7 7"
                  />
                </svg>
              </div>
            </div>
          </div>
        </div>

        <!-- Right: Selected Store Orders -->
        <div class="flex-1 border-l border-slate-200 pl-4">
          <div v-if="!selectedStore" class="text-center text-slate-500 mt-20">
            <svg
              class="w-12 h-12 mx-auto mb-4 text-slate-300"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 5l7 7-7 7"
              />
            </svg>
            <p class="text-sm">
              Level one - on opening the store specific accordion - list of
              orders
            </p>
          </div>

          <div v-else class="overflow-y-auto">
            <div class="space-y-3">
              <ZprotectOrderItem
                v-for="order in selectedStoreOrders"
                :key="order.id"
                :order="order"
                @cancel="handleCancelOrder"
                @refund="handleRefundOrder"
              />
            </div>
          </div>
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
