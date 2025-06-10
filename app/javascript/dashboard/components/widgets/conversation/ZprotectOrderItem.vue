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

const getOrderStatusClass = status => {
  const classes = {
    open: 'bg-blue-100 text-blue-800',
    closed: 'bg-green-100 text-green-800',
    cancelled: 'bg-gray-100 text-gray-800',
    archived: 'bg-yellow-100 text-yellow-800',
  };
  return classes[status?.toLowerCase()] || 'bg-slate-100 text-slate-800';
};

// Order action availability
const hasRefundableItems = computed(() => {
  return props.order.lineItems?.some(item => item.availableQuantity > 0);
});

const canCancel = computed(() => {
  const financial = props.order.financialStatus?.toLowerCase();
  const fulfillment = props.order.fulfillmentStatus?.toLowerCase();
  const orderStatus = props.order.orderStatus?.toLowerCase();

  // Cannot cancel if already cancelled or archived
  if (orderStatus === 'cancelled' || orderStatus === 'archived') {
    return false;
  }

  // Can cancel if paid but not fulfilled, or pending
  return (
    (financial === 'paid' && fulfillment !== 'fulfilled') ||
    financial === 'pending' ||
    financial === 'authorized'
  );
});

const canRefund = computed(() => {
  const financial = props.order.financialStatus?.toLowerCase();
  const orderStatus = props.order.orderStatus?.toLowerCase();

  // Cannot refund if cancelled or archived
  if (orderStatus === 'cancelled' || orderStatus === 'archived') {
    return false;
  }

  // Can refund if paid or partially paid and has refundable items
  return (
    (financial === 'paid' || financial === 'partially_paid') &&
    hasRefundableItems.value
  );
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

// Check if order has tracking information
const hasTrackingInfo = computed(() => {
  // Check for trackingInfoList array (correct ZProtect API format)
  if (
    props.order.trackingInfoList &&
    Array.isArray(props.order.trackingInfoList) &&
    props.order.trackingInfoList.length > 0
  ) {
    return true;
  }

  // Fallback to legacy flat fields for backward compatibility
  return !!(
    props.order.trackingNumber ||
    props.order.tracking_number ||
    props.order.trackingCompany ||
    props.order.tracking_company
  );
});

// Get tracking details
const trackingDetails = computed(() => {
  if (!hasTrackingInfo.value) return null;

  // Use trackingInfoList array (correct ZProtect API format)
  if (
    props.order.trackingInfoList &&
    Array.isArray(props.order.trackingInfoList) &&
    props.order.trackingInfoList.length > 0
  ) {
    const firstTracking = props.order.trackingInfoList[0];
    return {
      company: firstTracking.company || 'Carrier',
      number: firstTracking.number,
      url: firstTracking.url,
    };
  }

  // Fallback to legacy flat fields for backward compatibility
  return {
    company:
      props.order.trackingCompany || props.order.tracking_company || 'Carrier',
    number: props.order.trackingNumber || props.order.tracking_number,
    url: props.order.trackingUrl || props.order.tracking_url,
  };
});
</script>

<template>
  <div
    class="border border-slate-200 rounded-lg p-3 bg-white hover:shadow-sm transition-shadow"
  >
    <!-- Order Header with key info always visible -->
    <div class="mb-2">
      <!-- First row: Order number, date, and action buttons -->
      <div class="flex items-start justify-between mb-2">
        <div class="flex items-center flex-wrap gap-2">
          <span class="text-blue-600 font-semibold text-sm">
            {{ $t('ZPROTECT.ORDER_ITEM.ORDER_PREFIX') }}{{ displayOrderNumber }}
          </span>
          <span class="text-xs text-slate-600">
            {{ formatDate(order.createdAt || order.created_at) }}
          </span>
        </div>
        <!-- Action buttons always visible -->
        <div class="flex gap-1 flex-shrink-0 ml-2">
          <button
            v-if="canCancel"
            class="px-2 py-1 text-xs bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
            @click="handleCancel"
          >
            {{ $t('ZPROTECT.ORDER_ITEM.CANCEL_BUTTON') }}
          </button>
          <button
            v-if="canRefund && hasRefundableItems"
            class="px-2 py-1 text-xs bg-orange-500 text-white rounded hover:bg-orange-600 transition-colors"
            @click="handleRefund"
          >
            {{ $t('ZPROTECT.ORDER_ITEM.REFUND_BUTTON') }}
          </button>
        </div>
      </div>

      <!-- Second row: Price and item count -->
      <div class="text-xs text-slate-600 mb-1">
        {{ formatCurrency(orderTotal, order.currency) }}
        <span v-if="order.lineItems?.length" class="ml-2">
          {{ order.lineItems.length }}
          {{ $t('ZPROTECT.ORDER_ITEM.ITEMS_TEXT') }}
        </span>
      </div>

      <!-- Third row: Status badges -->
      <div class="flex flex-wrap items-center gap-2 text-xs">
        <div class="flex items-center gap-1">
          <span class="text-slate-600">{{
            $t('ZPROTECT.ORDER_ITEM.ORDER_STATUS')
          }}</span>
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-full"
            :class="getOrderStatusClass(order.orderStatus)"
          >
            {{ order.orderStatus || 'Unknown' }}
          </span>
        </div>
        <div class="flex items-center gap-1">
          <span class="text-slate-600">{{
            $t('ZPROTECT.ORDER_ITEM.FINANCIAL_STATUS')
          }}</span>
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-full"
            :class="
              getFinancialStatusClass(
                order.financialStatus || order.financial_status
              )
            "
          >
            {{ order.financialStatus || order.financial_status || 'Unknown' }}
          </span>
        </div>
        <div class="flex items-center gap-1">
          <span class="text-slate-600">{{
            $t('ZPROTECT.ORDER_ITEM.FULFILLMENT_STATUS')
          }}</span>
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-full"
            :class="
              getFulfillmentStatusClass(
                order.fulfillmentStatus || order.fulfillment_status
              )
            "
          >
            {{
              order.fulfillmentStatus || order.fulfillment_status || 'Unknown'
            }}
          </span>
        </div>
      </div>

      <!-- Fourth row: Tracking information (if available) -->
      <div v-if="hasTrackingInfo" class="flex items-center gap-2 text-xs mt-1">
        <span class="text-slate-600">
          {{ $t('ZPROTECT.ORDER_ITEM.TRACKING')
          }}{{ $t('ZPROTECT.ORDER_ITEM.SEPARATOR') }}
        </span>
        <span class="font-medium text-slate-800">
          {{ trackingDetails.company }}
          <span v-if="trackingDetails.number">
            {{ trackingDetails.number }}
          </span>
        </span>
        <a
          v-if="trackingDetails.url"
          :href="trackingDetails.url"
          target="_blank"
          rel="noopener noreferrer"
          class="text-blue-600 hover:text-blue-800 text-xs underline ml-1"
        >
          {{ $t('ZPROTECT.ORDER_ITEM.TRACK_PACKAGE') }}
        </a>
      </div>
    </div>

    <!-- Toggle details link -->
    <button
      class="text-xs text-blue-600 hover:text-blue-800 flex items-center"
      @click="toggleExpanded"
    >
      <span v-if="!isExpanded">{{
        $t('ZPROTECT.ORDER_ITEM.VIEW_DETAILS')
      }}</span>
      <span v-else>{{ $t('ZPROTECT.ORDER_ITEM.HIDE_DETAILS') }}</span>
      <svg
        class="w-3 h-3 ml-1 transition-transform"
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
    </button>

    <!-- Expanded Details -->
    <div
      v-if="isExpanded"
      class="mt-3 space-y-3 border-t border-slate-200 pt-3"
    >
      <!-- Line Items -->
      <div v-if="order.lineItems?.length">
        <div class="space-y-2">
          <div
            v-for="item in order.lineItems"
            :key="item.id"
            class="flex justify-between items-start p-2 bg-gray-50 rounded text-xs"
            :class="{
              'line-through opacity-50':
                item.refundedQuantity === item.quantity,
            }"
          >
            <div class="flex-1">
              <div class="font-medium text-slate-900">
                {{ item.title }}
              </div>
              <div v-if="item.variantTitle" class="text-xs text-slate-600">
                {{ item.variantTitle }}
              </div>
              <div class="text-xs text-slate-600">
                {{ $t('ZPROTECT.ORDER_ITEM.QUANTITY_TEXT') }}
                {{ item.quantity }}
                <span v-if="item.refundedQuantity > 0" class="text-red-600">
                  {{ $t('ZPROTECT.ORDER_ITEM.OPEN_PAREN')
                  }}{{ item.refundedQuantity }}
                  {{ $t('ZPROTECT.ORDER_ITEM.REFUNDED_TEXT')
                  }}{{ $t('ZPROTECT.ORDER_ITEM.CLOSE_PAREN') }}
                </span>
              </div>
            </div>
            <div class="text-right">
              <div class="font-medium">
                {{ formatCurrency(item.price, order.currency) }}
              </div>
              <div class="text-slate-600 text-xs">
                {{ $t('ZPROTECT.ORDER_ITEM.EACH_TEXT') }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Order totals -->
      <div class="space-y-1 text-xs border-t border-slate-200 pt-2">
        <div class="flex justify-between">
          <span class="text-slate-600">{{
            $t('ZPROTECT.ORDER_ITEM.TAXES')
          }}</span>
          <span class="text-blue-600">{{
            formatCurrency(
              order.totalTax || order.total_tax || 0,
              order.currency
            )
          }}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-600 italic">{{
            $t('ZPROTECT.ORDER_ITEM.SHIPPING')
          }}</span>
          <span class="text-blue-600">{{
            formatCurrency(
              order.totalShipping || order.total_shipping || 0,
              order.currency
            )
          }}</span>
        </div>
      </div>

      <!-- Tracking info if available -->
      <div v-if="hasTrackingInfo" class="border-t border-slate-200 pt-2">
        <div class="text-xs">
          <div class="font-medium text-slate-700 mb-1">
            {{ $t('ZPROTECT.ORDER_ITEM.TRACKING_INFO') }}
          </div>

          <!-- Handle trackingInfoList array (correct ZProtect API format) -->
          <div
            v-if="order.trackingInfoList && order.trackingInfoList.length > 0"
          >
            <div
              v-for="(tracking, index) in order.trackingInfoList"
              :key="index"
              class="flex items-center justify-between mb-1 last:mb-0"
            >
              <div class="text-slate-600">
                <span v-if="tracking.company">
                  {{ tracking.company }}
                </span>
                <span v-if="tracking.number" class="ml-2">
                  {{ tracking.number }}
                </span>
              </div>
              <a
                v-if="tracking.url"
                :href="tracking.url"
                target="_blank"
                rel="noopener noreferrer"
                class="text-blue-600 hover:text-blue-800 text-xs"
              >
                {{ $t('ZPROTECT.ORDER_ITEM.TRACK_PACKAGE') }}
              </a>
            </div>
          </div>

          <!-- Fallback to legacy flat fields for backward compatibility -->
          <div v-else class="flex items-center justify-between">
            <div class="text-slate-600">
              <span v-if="order.trackingCompany || order.tracking_company">
                {{ order.trackingCompany || order.tracking_company }}
              </span>
              <span
                v-if="order.trackingNumber || order.tracking_number"
                class="ml-2"
              >
                {{ order.trackingNumber || order.tracking_number }}
              </span>
            </div>
            <a
              v-if="order.trackingUrl || order.tracking_url"
              :href="order.trackingUrl || order.tracking_url"
              target="_blank"
              rel="noopener noreferrer"
              class="text-blue-600 hover:text-blue-800 text-xs"
            >
              {{ $t('ZPROTECT.ORDER_ITEM.TRACK_PACKAGE') }}
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Custom styles if needed */
</style>
