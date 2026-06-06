<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PhoneInput from 'dashboard/components/widgets/forms/PhoneInput.vue';
import wapiChannel from 'dashboard/api/channel/wapiChannel';

const props = defineProps({
  inboxId: { type: Number, required: true },
  connectErrorKey: {
    type: String,
    default: 'INBOX_MGMT.ADD.WAPI_INBOX.ERROR_CONNECT',
  },
});

const emit = defineEmits(['connected']);

const I18N = 'INBOX_MGMT.ADD.WAPI_INBOX';

const { t } = useI18n();

const qrCode = ref(null);
const loginCode = ref(null);
const phoneForCode = ref('');
const dialCode = ref('');
const showPairCode = ref(false);
const isLoading = ref(false);
const isConnecting = ref(false);
const pollingInterval = ref(null);
const qrRefreshTimer = ref(null);
const countdownInterval = ref(null);
const qrDuration = ref(30);
const qrSecondsRemaining = ref(null);

const stopCountdown = () => {
  if (countdownInterval.value) {
    clearInterval(countdownInterval.value);
    countdownInterval.value = null;
  }
  qrSecondsRemaining.value = null;
};

const startCountdown = () => {
  stopCountdown();
  qrSecondsRemaining.value = qrDuration.value;
  countdownInterval.value = setInterval(() => {
    if (qrSecondsRemaining.value > 0) {
      qrSecondsRemaining.value -= 1;
    }
  }, 1000);
};

const stopPolling = () => {
  if (pollingInterval.value) {
    clearInterval(pollingInterval.value);
    pollingInterval.value = null;
  }
  if (qrRefreshTimer.value) {
    clearInterval(qrRefreshTimer.value);
    qrRefreshTimer.value = null;
  }
  stopCountdown();
};

const fetchQr = async () => {
  try {
    const response = await wapiChannel.getQr(props.inboxId);
    if (response.data.success) {
      qrCode.value = response.data.qr;
      if (response.data.qr_duration) {
        qrDuration.value = response.data.qr_duration;
      }
      startCountdown();
    }
  } catch {
    // QR may not be available yet
  }
};

const startQrRefresh = () => {
  if (qrRefreshTimer.value) return;
  qrRefreshTimer.value = setInterval(fetchQr, qrDuration.value * 1000);
};

const connectDevice = async () => {
  isConnecting.value = true;
  try {
    await wapiChannel.connect(props.inboxId);
    stopPolling();
    emit('connected');
  } catch (error) {
    useAlert(error.response?.data?.error || t(props.connectErrorKey));
  } finally {
    isConnecting.value = false;
  }
};

const fetchStatus = async () => {
  try {
    const response = await wapiChannel.getStatus(props.inboxId);
    if (response.data.success && response.data.status === 'connected') {
      await connectDevice();
      return;
    }
    if (!showPairCode.value && !qrCode.value) await fetchQr();
    if (!showPairCode.value) startQrRefresh();
  } catch {
    // Ignore polling errors
  }
};

const startPolling = () => {
  fetchStatus();
  pollingInterval.value = setInterval(fetchStatus, 5000);
};

const formatPhoneForWapi = () => {
  const code = dialCode.value.replace(/^\+|^00/, '');
  const number = phoneForCode.value.replace(/[\s-]/g, '');
  return `${code}${number}`;
};

const onSetDialCode = code => {
  dialCode.value = code;
};

const requestPairCode = async () => {
  if (!phoneForCode.value || !dialCode.value) {
    useAlert(t(`${I18N}.PHONE_REQUIRED`));
    return;
  }
  isLoading.value = true;
  try {
    const formattedPhone = formatPhoneForWapi();
    const response = await wapiChannel.loginWithCode(
      props.inboxId,
      formattedPhone
    );
    if (response.data.success && response.data.pair_code) {
      loginCode.value = response.data.pair_code;
      stopPolling();
      startPolling();
    } else {
      useAlert(t(`${I18N}.ERROR_PAIR_CODE_NO_CODE`));
    }
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.ERROR_PAIR_CODE`));
  } finally {
    isLoading.value = false;
  }
};

const togglePairCode = () => {
  showPairCode.value = !showPairCode.value;
  loginCode.value = null;
  stopPolling();
  if (!showPairCode.value) startPolling();
};

const resetFlow = () => {
  qrCode.value = null;
  loginCode.value = null;
  showPairCode.value = false;
  stopPolling();
  startPolling();
};

watch(
  () => props.inboxId,
  () => resetFlow()
);

onMounted(() => {
  startPolling();
});

onUnmounted(() => {
  stopPolling();
});

defineExpose({ resetFlow, stopPolling });
</script>

<template>
  <div class="flex flex-col gap-3">
    <div v-if="showPairCode" class="flex flex-col gap-3">
      <h2 class="text-base font-medium text-n-slate-12">
        {{ $t(`${I18N}.PAIR_CODE_TITLE`) }}
      </h2>
      <p class="text-sm text-n-slate-11">
        {{ $t(`${I18N}.PAIR_CODE_HELP`) }}
      </p>
      <div class="flex flex-col gap-3 max-w-sm mx-auto w-full">
        <label class="text-sm font-medium text-n-slate-12">
          {{ $t(`${I18N}.PHONE_LABEL`) }}
        </label>
        <PhoneInput
          v-model="phoneForCode"
          :placeholder="$t(`${I18N}.PHONE_PLACEHOLDER`)"
          @set-code="onSetDialCode"
        />
        <NextButton
          solid
          blue
          :label="$t(`${I18N}.GET_PAIR_CODE`)"
          :is-loading="isLoading"
          @click="requestPairCode"
        />
        <div
          v-if="loginCode"
          class="p-4 rounded-xl border border-n-weak bg-n-alpha-2 text-center"
        >
          <div class="text-sm font-medium text-n-slate-11">
            {{ $t(`${I18N}.YOUR_CODE`) }}
          </div>
          <div class="text-3xl font-mono font-bold mt-2 text-n-slate-12">
            {{ loginCode }}
          </div>
          <p class="text-xs text-n-slate-10 mt-2">
            {{ $t(`${I18N}.PAIR_CODE_POLLING`) }}
          </p>
        </div>
        <div class="flex justify-center w-full mt-2">
          <NextButton
            variant="ghost"
            color="blue"
            size="sm"
            icon="i-lucide-qr-code"
            :label="$t(`${I18N}.BACK_TO_QR`)"
            @click="togglePairCode"
          />
        </div>
      </div>
    </div>

    <div v-else class="flex flex-col gap-3">
      <h2 class="text-base font-medium text-n-slate-12">
        {{ $t(`${I18N}.SCAN_QR_TITLE`) }}
      </h2>
      <p class="text-sm text-n-slate-11">
        {{ $t(`${I18N}.SCAN_QR_HELP`) }}
      </p>
      <div class="flex flex-col items-center gap-3 max-w-sm mx-auto w-full">
        <div
          v-if="qrCode"
          class="w-full max-w-[240px] rounded-xl border border-n-weak bg-n-solid-1 p-3"
        >
          <img
            :src="qrCode"
            :alt="$t(`${I18N}.QR_ALT`)"
            class="w-48 h-48 object-contain mx-auto"
          />
        </div>
        <div
          v-else
          class="flex flex-col items-center gap-2 py-8 text-sm text-n-slate-11"
        >
          <Spinner />
          <span>{{ $t(`${I18N}.WAITING_FOR_QR`) }}</span>
        </div>
        <p
          v-if="qrCode && qrSecondsRemaining > 0"
          class="text-sm text-n-slate-11"
        >
          {{ $t(`${I18N}.QR_EXPIRES_IN`, { seconds: qrSecondsRemaining }) }}
        </p>
        <p
          v-else-if="qrCode && qrSecondsRemaining === 0"
          class="flex items-center gap-2 text-sm text-n-slate-11"
        >
          <Spinner :size="16" />
          <span>{{ $t(`${I18N}.QR_REFRESHING`) }}</span>
        </p>
        <div class="flex justify-center w-full mt-2">
          <NextButton
            variant="ghost"
            color="blue"
            size="sm"
            icon="i-lucide-smartphone"
            :label="$t(`${I18N}.USE_PAIR_CODE`)"
            @click="togglePairCode"
          />
        </div>
      </div>
    </div>
  </div>
</template>
