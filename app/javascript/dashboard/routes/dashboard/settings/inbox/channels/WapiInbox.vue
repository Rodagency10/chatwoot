<script setup>
import { ref, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';
import PhoneInput from 'dashboard/components/widgets/forms/PhoneInput.vue';
import wapiChannel from 'dashboard/api/channel/wapiChannel';

const I18N = 'INBOX_MGMT.ADD.WAPI_INBOX';

const { t } = useI18n();
const router = useRouter();

const step = ref('form');
const inboxName = ref('');
const inboxId = ref(null);
const deviceCreated = ref(false);
const qrCode = ref(null);
const loginCode = ref(null);
const phoneForCode = ref('');
const dialCode = ref('');
const showPairCode = ref(false);
const isLoading = ref(false);
const isConnecting = ref(false);
const pollingInterval = ref(null);
const qrRefreshTimer = ref(null);
const qrDuration = ref(30);

const validationRules = { inboxName: { required } };
const v$ = useVuelidate(validationRules, { inboxName });

const stopPolling = () => {
  if (pollingInterval.value) {
    clearInterval(pollingInterval.value);
    pollingInterval.value = null;
  }
  if (qrRefreshTimer.value) {
    clearInterval(qrRefreshTimer.value);
    qrRefreshTimer.value = null;
  }
};

const fetchQr = async () => {
  try {
    const response = await wapiChannel.getQr(inboxId.value);
    if (response.data.success) {
      qrCode.value = response.data.qr;
      if (response.data.qr_duration) {
        qrDuration.value = response.data.qr_duration;
      }
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
    await wapiChannel.connect(inboxId.value);
    stopPolling();
    useAlert(t(`${I18N}.CONNECTED_SUCCESS`));
    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: inboxId.value },
    });
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.ERROR_CONNECT`));
  } finally {
    isConnecting.value = false;
  }
};

const fetchStatus = async () => {
  try {
    const response = await wapiChannel.getStatus(inboxId.value);
    if (response.data.success && response.data.status === 'connected') {
      await connectDevice();
      return;
    }
    // If disconnected and in QR mode, ensure QR is refreshing
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

const createInbox = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  isLoading.value = true;
  try {
    const response = await wapiChannel.createInbox(inboxName.value.trim());
    inboxId.value = response.data.inbox_id;
    deviceCreated.value = true;
    step.value = 'qr';
    startPolling();
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.ERROR_CREATE_INBOX`));
  } finally {
    isLoading.value = false;
  }
};

const formatPhoneForWapi = () => {
  // Format: dial code (without +/00) + local number
  // e.g. +228 70111810 → 22870111810
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
      inboxId.value,
      formattedPhone
    );
    if (response.data.success && response.data.pair_code) {
      loginCode.value = response.data.pair_code;
      // Start polling status to auto-connect once paired
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

onUnmounted(() => {
  stopPolling();
});
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t(`${I18N}.TITLE`)"
      :header-content="$t(`${I18N}.DESC`)"
    />

    <!-- Step 1: Create inbox form -->
    <form
      v-if="step === 'form'"
      class="flex flex-wrap flex-col mx-0"
      @submit.prevent="createInbox"
    >
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.inboxName.$error }">
          {{ $t(`${I18N}.INBOX_NAME_LABEL`) }}
          <input
            v-model="inboxName"
            type="text"
            :placeholder="$t(`${I18N}.INBOX_NAME_PLACEHOLDER`)"
            @blur="v$.inboxName.$touch"
          />
          <span v-if="v$.inboxName.$error" class="message">
            {{ $t(`${I18N}.INBOX_NAME_REQUIRED`) }}
          </span>
        </label>
      </div>
      <div class="w-full mt-4">
        <NextButton
          type="submit"
          solid
          blue
          :label="$t(`${I18N}.CREATE_BUTTON`)"
          :is-loading="isLoading"
        />
      </div>
    </form>

    <!-- Step 2: QR code / Pair code flow -->
    <template v-if="step === 'qr' && deviceCreated">
      <!-- Pair code mode -->
      <div v-if="showPairCode" class="flex flex-wrap flex-col mx-0">
        <h2 class="text-lg font-medium mb-2 text-n-slate-12">
          {{ $t(`${I18N}.PAIR_CODE_TITLE`) }}
        </h2>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t(`${I18N}.PAIR_CODE_HELP`) }}
        </p>
        <div class="flex-shrink-0 flex-grow-0">
          <label>
            {{ $t(`${I18N}.PHONE_LABEL`) }}
          </label>
          <PhoneInput
            v-model="phoneForCode"
            :placeholder="$t(`${I18N}.PHONE_PLACEHOLDER`)"
            @set-code="onSetDialCode"
          />
        </div>
        <div class="w-full mt-4">
          <NextButton
            solid
            blue
            :label="$t(`${I18N}.GET_PAIR_CODE`)"
            :is-loading="isLoading"
            @click="requestPairCode"
          />
        </div>
        <div
          v-if="loginCode"
          class="mt-4 p-4 rounded-xl border border-n-weak bg-n-alpha-2"
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
        <button
          class="mt-4 text-sm text-n-brand cursor-pointer"
          @click="togglePairCode"
        >
          {{ $t(`${I18N}.BACK_TO_QR`) }}
        </button>
      </div>

      <!-- QR code mode -->
      <div v-else class="flex flex-wrap flex-col mx-0">
        <h2 class="text-lg font-medium mb-2 text-n-slate-12">
          {{ $t(`${I18N}.SCAN_QR_TITLE`) }}
        </h2>
        <p class="text-sm text-n-slate-11 mb-4">
          {{ $t(`${I18N}.SCAN_QR_HELP`) }}
        </p>
        <div v-if="qrCode" class="mb-4 flex justify-center">
          <img
            :src="qrCode"
            :alt="$t(`${I18N}.QR_ALT`)"
            class="border border-n-weak rounded-xl p-2"
          />
        </div>
        <div v-else class="mb-4 text-sm text-n-slate-11">
          {{ $t(`${I18N}.WAITING_FOR_QR`) }}
        </div>
        <button
          class="text-sm text-n-brand mb-4 cursor-pointer text-left"
          @click="togglePairCode"
        >
          {{ $t(`${I18N}.USE_PAIR_CODE`) }}
        </button>
      </div>
    </template>
  </div>
</template>
