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
</script>

<template>
  <div
    class="border border-slate-200 rounded-lg p-4 bg-white hover:shadow-sm transition-shadow"
  >
    <!-- Order Header with key info always visible -->
    <div class="flex items-start justify-between mb-3">
      <div class="flex-1">
        <!-- Order Number and Status -->
        <div class="flex items-center space-x-2 mb-2">
          <span class="text-blue-600 font-semibold text-lg">
            {{ $t('ZPROTECT.ORDER_ITEM.ORDER_PREFIX') }}{{ displayOrderNumber }}
          </span>
          <span class="text-sm text-slate-600">
            {{ formatDate(order.createdAt || order.created_at) }}
          </span>
        </div>

        <!-- Price and item count -->
        <div class="text-sm text-slate-600 mb-2">
          {{ formatCurrency(orderTotal, order.currency) }}
          <span v-if="order.lineItems?.length" class="ml-2">
            {{ order.lineItems.length }}
            {{ $t('ZPROTECT.ORDER_ITEM.ITEMS_TEXT') }}
          </span>
        </div>

        <!-- Status info -->
        <div class="flex items-center space-x-2 text-sm">
          <span class="text-slate-600">{{
            $t('ZPROTECT.ORDER_ITEM.FINANCIAL_STATUS')
          }}</span>
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
          <span class="text-slate-600 ml-4">{{
            $t('ZPROTECT.ORDER_ITEM.FULFILLMENT_STATUS')
          }}</span>
          <span
            class="px-2 py-1 text-xs font-medium rounded-full"
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

      <!-- Action buttons always visible -->
      <div class="flex space-x-2">
        <button
          v-if="canCancel"
          class="px-3 py-1 text-sm bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
          @click="handleCancel"
        >
          {{ $t('ZPROTECT.ORDER_ITEM.CANCEL_BUTTON') }}
        </button>
        <button
          v-if="canRefund && hasRefundableItems"
          class="px-3 py-1 text-sm bg-orange-500 text-white rounded hover:bg-orange-600 transition-colors"
          @click="handleRefund"
        >
          {{ $t('ZPROTECT.ORDER_ITEM.REFUND_BUTTON') }}
        </button>
      </div>
    </div>

    <!-- Toggle details link -->
    <button
      class="text-sm text-blue-600 hover:text-blue-800 flex items-center mt-2"
      @click="toggleExpanded"
    >
      <span v-if="!isExpanded">{{
        $t('ZPROTECT.ORDER_ITEM.VIEW_DETAILS')
      }}</span>
      <span v-else>{{ $t('ZPROTECT.ORDER_ITEM.HIDE_DETAILS') }}</span>
      <svg
        class="w-4 h-4 ml-1 transition-transform"
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
      class="mt-4 space-y-4 border-t border-slate-200 pt-4"
    >
      <!-- Line Items -->
      <div v-if="order.lineItems?.length">
        <div class="space-y-3">
          <div
            v-for="item in order.lineItems"
            :key="item.id"
            class="flex justify-between items-start p-3 bg-gray-50 rounded"
            :class="{
              'line-through opacity-50':
                item.refundedQuantity === item.quantity,
            }"
          >
            <div class="flex-1">
              <div class="font-medium text-slate-900">
                {{ item.title }}
              </div>
              <div v-if="item.variantTitle" class="text-sm text-slate-600">
                {{ item.variantTitle }}
              </div>
              <div class="text-sm text-slate-600">
                {{ $t('ZPROTECT.ORDER_ITEM.QUANTITY_TEXT') }}
                {{ item.quantity }}
                <span v-if="item.refundedQuantity > 0" class="text-red-600">
                  ({{ item.refundedQuantity }}
                  {{ $t('ZPROTECT.ORDER_ITEM.REFUNDED_TEXT') }})
                </span>
                <span class="ml-2">{{
                  $t('ZPROTECT.ORDER_ITEM.REFUNDED_LINE_ITEMS')
                }}</span>
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
      <div class="space-y-2 text-sm border-t border-slate-200 pt-3">
        <div class="flex justify-between">
          <span class="text-slate-600">{{
            $t('ZPROTECT.ORDER_ITEM.TAXES')
          }}</span>
          <span class="text-blue-600">{{ formatCurrency(3.15, 'USD') }}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-slate-600 italic">{{
            $t('ZPROTECT.ORDER_ITEM.FREE_SHIPPING')
          }}</span>
          <span class="text-blue-600">{{ formatCurrency(0, 'USD') }}</span>
        </div>
      </div>

      <!-- Bottom action buttons -->
      <div class="flex space-x-2 pt-3 border-t border-slate-200">
        <button
          v-if="canCancel"
          class="px-4 py-2 text-sm bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
          @click="handleCancel"
        >
          {{ $t('ZPROTECT.ORDER_ITEM.CANCEL_BUTTON') }}
        </button>
        <button
          v-if="canRefund && hasRefundableItems"
          class="px-4 py-2 text-sm bg-orange-500 text-white rounded hover:bg-orange-600 transition-colors"
          @click="handleRefund"
        >
          {{ $t('ZPROTECT.ORDER_ITEM.REFUND_BUTTON') }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Custom styles if needed */
</style>
