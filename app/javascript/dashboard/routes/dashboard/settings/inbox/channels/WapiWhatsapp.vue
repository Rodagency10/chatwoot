<script setup>
import { ref, onUnmounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useStore } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';
import wapiChannel from 'dashboard/api/channel/wapiChannel';

const I18N = 'INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const uiFlags = useMapGetter('inboxes/getUIFlags');
const currentUser = computed(() => store.getters['auth/getCurrentUser']);
const apiToken = computed(() => currentUser.value?.access_token || '');

const step = ref('form');
const inboxName = ref('');
const inboxId = ref(null);
const deviceCreated = ref(false);
const qrCode = ref(null);
const loginCode = ref(null);
const phoneForCode = ref('');
const showPairCode = ref(false);
const status = ref(null);
const isDeviceLoading = ref(false);
const isConnecting = ref(false);
const pollingInterval = ref(null);

const validationRules = {
  inboxName: { required },
};
const v$ = useVuelidate(validationRules, { inboxName });

const qrRefreshTimer = ref(null);
const qrDuration = ref(30);

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
    // QR may not be available if already connected
  }
};

const startQrRefresh = () => {
  if (qrRefreshTimer.value) return;
  qrRefreshTimer.value = setInterval(fetchQr, qrDuration.value * 1000);
};

const fetchStatus = async () => {
  try {
    const response = await wapiChannel.getStatus(inboxId.value);
    if (response.data.success) {
      const newStatus = response.data.status;
      status.value = newStatus;

      if (newStatus === 'qr' || newStatus === 'disconnected') {
        if (!qrCode.value) await fetchQr();
        startQrRefresh();
      } else if (newStatus === 'connected') {
        stopPolling();
        useAlert(t(`${I18N}.CONNECTED_SUCCESS`));
        router.replace({
          name: 'settings_inboxes_add_agents',
          params: { page: 'new', inbox_id: inboxId.value },
        });
      }
    }
  } catch {
    // Ignore polling errors
  }
};

const startPolling = () => {
  fetchStatus();
  pollingInterval.value = setInterval(fetchStatus, 5000);
};

const createDevice = async () => {
  try {
    await wapiChannel.createDevice(inboxId.value);
    deviceCreated.value = true;
    startPolling();
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.ERROR_CREATE_DEVICE`));
  } finally {
    isDeviceLoading.value = false;
  }
};

const createInbox = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) {
    return;
  }

  isDeviceLoading.value = true;
  try {
    const inbox = await store.dispatch('inboxes/createChannel', {
      name: inboxName.value.trim(),
      channel: {
        type: 'whatsapp',
        provider: 'wapi',
        provider_config: {},
      },
    });
    inboxId.value = inbox.id;
    step.value = 'qr';
    await createDevice();
  } catch (error) {
    useAlert(error.response?.data?.message || t(`${I18N}.ERROR_CREATE_INBOX`));
    isDeviceLoading.value = false;
  }
};

const requestPairCode = async () => {
  if (!phoneForCode.value) {
    useAlert(t(`${I18N}.PHONE_REQUIRED`));
    return;
  }
  isDeviceLoading.value = true;
  try {
    const response = await wapiChannel.loginWithCode(
      inboxId.value,
      phoneForCode.value
    );
    if (response.data.success && response.data.data?.code) {
      loginCode.value = response.data.data.code;
    } else {
      useAlert(t(`${I18N}.ERROR_PAIR_CODE_NO_CODE`));
    }
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.ERROR_PAIR_CODE`));
  } finally {
    isDeviceLoading.value = false;
  }
};

const connectDevice = async () => {
  if (!apiToken.value) {
    useAlert(t(`${I18N}.API_TOKEN_REQUIRED`));
    return;
  }
  isConnecting.value = true;
  try {
    await wapiChannel.connectDevice(inboxId.value, apiToken.value);
    useAlert(t(`${I18N}.CONNECT_SUCCESS`));
    startPolling();
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.ERROR_CONNECT`));
  } finally {
    isConnecting.value = false;
  }
};

const togglePairCode = () => {
  showPairCode.value = !showPairCode.value;
  stopPolling();
  if (!showPairCode.value) {
    startPolling();
  }
};

onUnmounted(() => {
  stopPolling();
});
</script>

<template>
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
        :is-loading="uiFlags.isCreating"
      />
    </div>
  </form>

  <!-- Step 2: Device creation loading -->
  <div
    v-if="step === 'qr' && isDeviceLoading && !deviceCreated"
    class="text-center py-8"
  >
    <div class="text-lg font-medium mb-2 text-n-slate-12">
      {{ $t(`${I18N}.CREATING_DEVICE`) }}
    </div>
    <div class="text-sm text-n-slate-11">
      {{ $t(`${I18N}.PLEASE_WAIT`) }}
    </div>
  </div>

  <!-- Step 3: QR code / Pair code flow -->
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
          <input
            v-model="phoneForCode"
            type="text"
            :placeholder="$t(`${I18N}.PHONE_PLACEHOLDER`)"
          />
        </label>
      </div>
      <div class="w-full mt-4">
        <NextButton
          solid
          blue
          :label="$t(`${I18N}.GET_PAIR_CODE`)"
          :is-loading="isDeviceLoading"
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

      <div class="mt-6 border-t border-n-weak pt-6">
        <h3 class="text-sm font-medium mb-2 text-n-slate-12">
          {{ $t(`${I18N}.CONNECT_SECTION`) }}
        </h3>
        <NextButton
          solid
          blue
          :label="$t(`${I18N}.CONNECT_BUTTON`)"
          :is-loading="isConnecting"
          @click="connectDevice"
        />
      </div>
    </div>
  </template>
</template>
