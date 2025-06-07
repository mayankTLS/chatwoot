<script setup>
import { ref, computed } from 'vue';
// import { useI18n } from 'vue-i18n'; // Disabled for now as we use $t in template
import { format } from 'date-fns';

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['cancel', 'refund']);

// const { t } = useI18n(); // Disabled for now as we use $t in template

const isExpanded = ref(false);

const formatDate = dateString => {
  return format(new Date(dateString), 'MMM d, yyyy HH:mm');
};

const formatCurrency = (amount, currency) => {
  return new Intl.NumberFormat('en', {
    style: 'currency',
    currency: currency || 'USD',
  }).format(amount);
};

// Status badge styling
const getFinancialStatusClass = status => {
  const classes = {
    paid: 'bg-green-100 text-green-800',
    pending: 'bg-yellow-100 text-yellow-800',
    authorized: 'bg-blue-100 text-blue-800',
    partially_paid: 'bg-orange-100 text-orange-800',
    refunded: 'bg-gray-100 text-gray-800',
    voided: 'bg-red-100 text-red-800',
    partially_refunded: 'bg-purple-100 text-purple-800',
  };
  return classes[status?.toLowerCase()] || 'bg-slate-100 text-slate-800';
};

const getFulfillmentStatusClass = status => {
  const classes = {
    fulfilled: 'bg-green-100 text-green-800',
    partial: 'bg-yellow-100 text-yellow-800',
    unfulfilled: 'bg-red-100 text-red-800',
    restocked: 'bg-blue-100 text-blue-800',
  };
  return classes[status?.toLowerCase()] || 'bg-slate-100 text-slate-800';
};

// Order action availability
const canCancel = computed(() => {
  const financial = props.order.financialStatus?.toLowerCase();
  const fulfillment = props.order.fulfillmentStatus?.toLowerCase();

  // Can cancel if paid but not fulfilled, or pending
  return (
    (financial === 'paid' && fulfillment !== 'fulfilled') ||
    financial === 'pending' ||
    financial === 'authorized'
  );
});

const canRefund = computed(() => {
  const financial = props.order.financialStatus?.toLowerCase();

  // Can refund if paid or partially paid
  return financial === 'paid' || financial === 'partially_paid';
});

const hasRefundableItems = computed(() => {
  return props.order.lineItems?.some(item => item.availableQuantity > 0);
});

// Calculate totals including extras
// const orderSubtotal = computed(() => {
//   return props.order.lineItems?.reduce((sum, item) => {
//     return sum + (parseFloat(item.price) * item.quantity);
//   }, 0) || 0;
// });

const orderTotal = computed(() => {
  let total = parseFloat(props.order.totalPrice || 0);
  return total;
});

const toggleExpanded = () => {
  isExpanded.value = !isExpanded.value;
};

const handleCancel = () => {
  emit('cancel', props.order);
};

const handleRefund = () => {
  emit('refund', props.order);
};

// Extract order number from id or orderNumber field
const displayOrderNumber = computed(() => {
  return (
    props.order.orderNumber ||
    props.order.order_number ||
    props.order.name?.replace('#', '') ||
    props.order.id?.toString().split('/').pop()
  );
});

// External link to Shopify admin (if order has proper GID)
const shopifyAdminUrl = computed(() => {
  if (props.order.id?.includes('gid://shopify/Order/')) {
    // const orderId = props.order.id.split('/').pop();
    // Note: Would need store domain to construct proper URL
    return null; // Disabled for now
  }
  return null;
});
</script>

<template>
  <div class="p-3 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors">
    <!-- Order Header -->
    <div
      class="flex items-center justify-between cursor-pointer"
      @click="toggleExpanded"
    >
      <div class="flex-1 min-w-0">
        <!-- Order ID and Date -->
        <div class="flex items-center space-x-2 mb-1">
          <span
            class="font-mono text-sm font-medium text-slate-900 dark:text-slate-100"
          >
            {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.ORDER_PREFIX')
            }}{{ displayOrderNumber }}
          </span>
          <a
            v-if="shopifyAdminUrl"
            :href="shopifyAdminUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="text-blue-600 hover:text-blue-800 text-xs"
            @click.stop
          >
            <svg
              class="w-3 h-3"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
              />
            </svg>
          </a>
        </div>

        <!-- Date and Total -->
        <div class="flex items-center justify-between text-sm">
          <span class="text-slate-600 dark:text-slate-400">
            {{ formatDate(order.createdAt || order.created_at) }}
          </span>
          <span class="font-medium text-slate-900 dark:text-slate-100">
            {{ formatCurrency(orderTotal, order.currency) }}
          </span>
        </div>
      </div>

      <!-- Expand/Collapse Icon -->
      <svg
        class="w-4 h-4 ml-2 text-slate-400 transition-transform"
        :class="{ 'rotate-180': isExpanded }"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M19 9l-7 7-7-7"
        />
      </svg>
    </div>

    <!-- Status Badges -->
    <div class="flex flex-wrap gap-2 mt-2">
      <span
        class="px-2 py-1 text-xs font-medium rounded-full"
        :class="
          getFinancialStatusClass(
            order.financialStatus || order.financial_status
          )
        "
      >
        {{ order.financialStatus || order.financial_status || 'Unknown' }}
      </span>
      <span
        class="px-2 py-1 text-xs font-medium rounded-full"
        :class="
          getFulfillmentStatusClass(
            order.fulfillmentStatus || order.fulfillment_status
          )
        "
      >
        {{ order.fulfillmentStatus || order.fulfillment_status || 'Unknown' }}
      </span>
    </div>

    <!-- Expanded Details -->
    <div
      v-if="isExpanded"
      class="mt-4 space-y-4 border-t border-slate-200 dark:border-slate-700 pt-4"
    >
      <!-- Line Items -->
      <div v-if="order.lineItems?.length">
        <h5 class="text-sm font-medium text-slate-900 dark:text-slate-100 mb-2">
          {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.LINE_ITEMS') }}
        </h5>
        <div class="space-y-2">
          <div
            v-for="item in order.lineItems"
            :key="item.id"
            class="flex justify-between items-start text-sm"
          >
            <div class="flex-1 min-w-0">
              <div class="font-medium text-slate-900 dark:text-slate-100">
                {{ item.title }}
              </div>
              <div
                v-if="item.variantTitle"
                class="text-slate-600 dark:text-slate-400"
              >
                {{ item.variantTitle }}
              </div>
              <div class="text-slate-600 dark:text-slate-400">
                {{ $t('CONVERSATION.ZPROTECT.REFUND_MODAL.QUANTITY_LABEL') }}
                {{ item.quantity }}
                <span v-if="item.refundedQuantity > 0" class="text-red-600">
                  {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.OPEN_PAREN')
                  }}{{ item.refundedQuantity }}
                  {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.REFUNDED')
                  }}{{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.CLOSE_PAREN') }}
                </span>
                <span
                  v-if="item.availableQuantity !== item.quantity"
                  class="text-green-600"
                >
                  {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.OPEN_PAREN')
                  }}{{ item.availableQuantity }}
                  {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.AVAILABLE')
                  }}{{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.CLOSE_PAREN') }}
                </span>
              </div>
            </div>
            <div class="text-right">
              <div class="font-medium">
                {{ formatCurrency(item.price, order.currency) }}
              </div>
              <div class="text-slate-600 dark:text-slate-400 text-xs">
                {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.EACH') }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Order Extras (taxes, discounts, shipping) -->
      <div class="space-y-2 text-sm">
        <div v-if="order.taxes?.amount > 0" class="flex justify-between">
          <span class="text-slate-600 dark:text-slate-400">{{
            $t('CONVERSATION.ZPROTECT.ORDER_ITEM.TAXES')
          }}</span>
          <span>{{
            formatCurrency(order.taxes.amount, order.taxes.currency)
          }}</span>
        </div>
        <div v-if="order.discounts?.amount > 0" class="flex justify-between">
          <span class="text-slate-600 dark:text-slate-400">{{
            $t('CONVERSATION.ZPROTECT.ORDER_ITEM.DISCOUNT')
          }}</span>
          <span class="text-green-600">
            {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.DISCOUNT_PREFIX')
            }}{{
              formatCurrency(order.discounts.amount, order.discounts.currency)
            }}
          </span>
        </div>
        <div
          v-if="order.shippingCharges?.amount > 0"
          class="flex justify-between"
        >
          <span class="text-slate-600 dark:text-slate-400">{{
            order.shippingCharges.title ||
            $t('CONVERSATION.ZPROTECT.ORDER_ITEM.SHIPPING')
          }}</span>
          <span>{{
            formatCurrency(
              order.shippingCharges.amount,
              order.shippingCharges.currency
            )
          }}</span>
        </div>
        <div
          class="flex justify-between font-medium border-t border-slate-200 dark:border-slate-700 pt-2"
        >
          <span>{{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.TOTAL') }}</span>
          <span>{{ formatCurrency(orderTotal, order.currency) }}</span>
        </div>
      </div>

      <!-- Tracking Information -->
      <div v-if="order.trackingInfoList?.length" class="space-y-2">
        <h5 class="text-sm font-medium text-slate-900 dark:text-slate-100">
          {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.TRACKING') }}
        </h5>
        <div
          v-for="tracking in order.trackingInfoList"
          :key="tracking.number"
          class="text-sm"
        >
          <div class="flex items-center justify-between">
            <span class="text-slate-600 dark:text-slate-400">{{
              tracking.company
            }}</span>
            <a
              v-if="tracking.url"
              :href="tracking.url"
              target="_blank"
              rel="noopener noreferrer"
              class="text-blue-600 hover:text-blue-800 font-mono"
            >
              {{ tracking.number }}
            </a>
            <span v-else class="font-mono">{{ tracking.number }}</span>
          </div>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex space-x-2 pt-2">
        <button
          v-if="canCancel"
          class="px-3 py-1 text-sm bg-red-100 text-red-800 rounded hover:bg-red-200 transition-colors"
          @click="handleCancel"
        >
          {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.CANCEL_BUTTON') }}
        </button>
        <button
          v-if="canRefund && hasRefundableItems"
          class="px-3 py-1 text-sm bg-blue-100 text-blue-800 rounded hover:bg-blue-200 transition-colors"
          @click="handleRefund"
        >
          {{ $t('CONVERSATION.ZPROTECT.ORDER_ITEM.REFUND_BUTTON') }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Custom styles if needed */
</style>
