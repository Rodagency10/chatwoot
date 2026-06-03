<script setup>
import { ref, onUnmounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'vuex';
import NextButton from 'dashboard/components-next/button/Button.vue';
import wapiChannel from 'dashboard/api/channel/wapiChannel';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

const step = ref('form');
const inboxName = ref('');
const inboxId = ref(null);
const deviceCreated = ref(false);
const qrCode = ref(null);
const loginCode = ref(null);
const phoneForCode = ref('');
const showPairCode = ref(false);
const status = ref(null);
const isLoading = ref(false);
const isConnecting = ref(false);
const pollingInterval = ref(null);

const currentUser = computed(() => store.getters['auth/getCurrentUser']);
const apiToken = computed(() => currentUser.value?.access_token || '');

const stopPolling = () => {
  if (pollingInterval.value) {
    clearInterval(pollingInterval.value);
    pollingInterval.value = null;
  }
};

const fetchQr = async () => {
  try {
    const response = await wapiChannel.getQr(inboxId.value);
    if (response.data.success) {
      qrCode.value = response.data.qr;
    }
  } catch (error) {
    // QR may not be available if already connected
  }
};

const fetchStatus = async () => {
  try {
    const response = await wapiChannel.getStatus(inboxId.value);
    if (response.data.success) {
      const newStatus = response.data.status;
      status.value = newStatus;

      if (newStatus === 'qr' || newStatus === 'disconnected') {
        await fetchQr();
      } else if (newStatus === 'connected') {
        stopPolling();
        useAlert(t('WAPI.ONBOARDING.CONNECTED_SUCCESS'));
        router.replace({
          name: 'settings_inboxes_add_agents',
          params: { page: 'new', inbox_id: inboxId.value },
        });
      }
    }
  } catch (error) {
    // Ignore polling errors
  }
};

const startPolling = () => {
  fetchStatus();
  pollingInterval.value = setInterval(fetchStatus, 3000);
};

const createDevice = async () => {
  try {
    await wapiChannel.createDevice(inboxId.value);
    deviceCreated.value = true;
    startPolling();
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('WAPI.ONBOARDING.ERROR_CREATE_DEVICE')
    );
  } finally {
    isLoading.value = false;
  }
};

const createInbox = async () => {
  if (!inboxName.value.trim()) {
    useAlert(t('WAPI.ONBOARDING.INBOX_NAME_REQUIRED'));
    return;
  }
  
  isLoading.value = true;
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
    useAlert(
      error.response?.data?.message || t('WAPI.ONBOARDING.ERROR_CREATE_INBOX')
    );
    isLoading.value = false;
  }
};

const requestPairCode = async () => {
  if (!phoneForCode.value) {
    useAlert(t('WAPI.ONBOARDING.PHONE_REQUIRED'));
    return;
  }
  isLoading.value = true;
  try {
    const response = await wapiChannel.loginWithCode(
      inboxId.value,
      phoneForCode.value
    );
    if (response.data.success && response.data.data?.code) {
      loginCode.value = response.data.data.code;
    } else {
      useAlert(t('WAPI.ONBOARDING.ERROR_PAIR_CODE_NO_CODE'));
    }
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('WAPI.ONBOARDING.ERROR_PAIR_CODE')
    );
  } finally {
    isLoading.value = false;
  }
};

const connectDevice = async () => {
  if (!apiToken.value) {
    useAlert(t('WAPI.ONBOARDING.API_TOKEN_REQUIRED'));
    return;
  }
  isConnecting.value = true;
  try {
    await wapiChannel.connectDevice(inboxId.value, apiToken.value);
    useAlert(t('WAPI.ONBOARDING.CONNECT_SUCCESS'));
    startPolling();
  } catch (error) {
    useAlert(error.response?.data?.error || t('WAPI.ONBOARDING.ERROR_CONNECT'));
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
  <div class="flex flex-col items-center justify-center p-8">
    <div v-if="step === 'form'" class="w-full max-w-md">
      <h2 class="text-xl font-semibold mb-4">
        {{ $t('WAPI.ONBOARDING.CREATE_INBOX_TITLE') }}
      </h2>
      <div class="mb-4">
        <label class="block text-sm font-medium mb-1">
          {{ $t('WAPI.ONBOARDING.INBOX_NAME_LABEL') }}
        </label>
        <input
          v-model="inboxName"
          type="text"
          :placeholder="$t('WAPI.ONBOARDING.INBOX_NAME_PLACEHOLDER')"
          class="w-full px-3 py-2 border rounded"
        />
      </div>
      <NextButton
        :label="$t('WAPI.ONBOARDING.CREATE_BUTTON')"
        :is-loading="isLoading"
        @click="createInbox"
      />
    </div>

    <div v-if="step === 'qr' && isLoading && !deviceCreated" class="text-center">
      <div class="text-lg font-medium mb-2">
        {{ $t('WAPI.ONBOARDING.CREATING_DEVICE') }}
      </div>
      <div class="text-sm text-slate-500">
        {{ $t('WAPI.ONBOARDING.PLEASE_WAIT') }}
      </div>
    </div>

    <template v-if="step === 'qr' && deviceCreated">
      <div v-if="showPairCode" class="w-full max-w-md">
        <h2 class="text-xl font-semibold mb-4">
          {{ $t('WAPI.ONBOARDING.PAIR_CODE_TITLE') }}
        </h2>
        <div class="mb-4">
          <label class="block text-sm font-medium mb-1">
            {{ $t('WAPI.ONBOARDING.PHONE_LABEL') }}
          </label>
          <input
            v-model="phoneForCode"
            type="text"
            :placeholder="$t('WAPI.ONBOARDING.PHONE_PLACEHOLDER')"
            class="w-full px-3 py-2 border rounded"
          />
        </div>
        <NextButton
          :label="$t('WAPI.ONBOARDING.GET_PAIR_CODE')"
          :is-loading="isLoading"
          @click="requestPairCode"
        />
        <div v-if="loginCode" class="mt-4 p-4 bg-green-50 rounded">
          <div class="text-sm font-medium">
            {{ $t('WAPI.ONBOARDING.YOUR_CODE') }}
          </div>
          <div class="text-3xl font-mono font-bold mt-2">{{ loginCode }}</div>
        </div>
        <button class="mt-4 text-sm text-woot-500" @click="togglePairCode">
          {{ $t('WAPI.ONBOARDING.BACK_TO_QR') }}
        </button>
      </div>

      <div v-else class="w-full max-w-md text-center">
        <h2 class="text-xl font-semibold mb-4">
          {{ $t('WAPI.ONBOARDING.SCAN_QR_TITLE') }}
        </h2>
        <div v-if="qrCode" class="mb-4">
          <img
            :src="qrCode"
            :alt="$t('WAPI.ONBOARDING.QR_ALT')"
            class="mx-auto border rounded p-2"
          />
        </div>
        <div v-else class="mb-4 text-sm text-slate-500">
          {{ $t('WAPI.ONBOARDING.WAITING_FOR_QR') }}
        </div>
        <button class="text-sm text-woot-500 mb-4" @click="togglePairCode">
          {{ $t('WAPI.ONBOARDING.USE_PAIR_CODE') }}
        </button>

        <div class="mt-6 border-t pt-6">
          <h3 class="text-sm font-medium mb-2">
            {{ $t('WAPI.ONBOARDING.CONNECT_SECTION') }}
          </h3>
          <NextButton
            :label="$t('WAPI.ONBOARDING.CONNECT_BUTTON')"
            :is-loading="isConnecting"
            @click="connectDevice"
          />
        </div>
      </div>
    </template>
  </div>
</template>
