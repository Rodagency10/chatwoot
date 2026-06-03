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
  } catch {
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
        useAlert(
          t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.CONNECTED_SUCCESS')
        );
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
  pollingInterval.value = setInterval(fetchStatus, 3000);
};

const createDevice = async () => {
  try {
    await wapiChannel.createDevice(inboxId.value);
    deviceCreated.value = true;
    startPolling();
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.ERROR_CREATE_DEVICE')
    );
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
    useAlert(
      error.response?.data?.message ||
        t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.ERROR_CREATE_INBOX')
    );
    isDeviceLoading.value = false;
  }
};

const requestPairCode = async () => {
  if (!phoneForCode.value) {
    useAlert(
      t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.PHONE_REQUIRED')
    );
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
      useAlert(
        t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.ERROR_PAIR_CODE_NO_CODE')
      );
    }
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.ERROR_PAIR_CODE')
    );
  } finally {
    isDeviceLoading.value = false;
  }
};

const connectDevice = async () => {
  if (!apiToken.value) {
    useAlert(
      t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.API_TOKEN_REQUIRED')
    );
    return;
  }
  isConnecting.value = true;
  try {
    await wapiChannel.connectDevice(inboxId.value, apiToken.value);
    useAlert(
      t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.CONNECT_SUCCESS')
    );
    startPolling();
  } catch (error) {
    useAlert(
      error.response?.data?.error ||
        t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.ERROR_CONNECT')
    );
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
        {{
          $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.INBOX_NAME_LABEL')
        }}
        <input
          v-model="inboxName"
          type="text"
          :placeholder="
            $t(
              'INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.INBOX_NAME_PLACEHOLDER'
            )
          "
          @blur="v$.inboxName.$touch"
        />
        <span v-if="v$.inboxName.$error" class="message">
          {{
            $t(
              'INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.INBOX_NAME_REQUIRED'
            )
          }}
        </span>
      </label>
    </div>
    <div class="w-full mt-4">
      <NextButton
        type="submit"
        solid
        blue
        :label="
          $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.CREATE_BUTTON')
        "
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
      {{
        $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.CREATING_DEVICE')
      }}
    </div>
    <div class="text-sm text-n-slate-11">
      {{ $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.PLEASE_WAIT') }}
    </div>
  </div>

  <!-- Step 3: QR code / Pair code flow -->
  <template v-if="step === 'qr' && deviceCreated">
    <!-- Pair code mode -->
    <div v-if="showPairCode" class="flex flex-wrap flex-col mx-0">
      <h2 class="text-lg font-medium mb-4 text-n-slate-12">
        {{
          $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.PAIR_CODE_TITLE')
        }}
      </h2>
      <div class="flex-shrink-0 flex-grow-0">
        <label>
          {{
            $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.PHONE_LABEL')
          }}
          <input
            v-model="phoneForCode"
            type="text"
            :placeholder="
              $t(
                'INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.PHONE_PLACEHOLDER'
              )
            "
          />
        </label>
      </div>
      <div class="w-full mt-4">
        <NextButton
          solid
          blue
          :label="
            $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.GET_PAIR_CODE')
          "
          :is-loading="isDeviceLoading"
          @click="requestPairCode"
        />
      </div>
      <div
        v-if="loginCode"
        class="mt-4 p-4 rounded-xl border border-n-weak bg-n-alpha-2"
      >
        <div class="text-sm font-medium text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.YOUR_CODE') }}
        </div>
        <div class="text-3xl font-mono font-bold mt-2 text-n-slate-12">
          {{ loginCode }}
        </div>
      </div>
      <button
        class="mt-4 text-sm text-n-brand cursor-pointer"
        @click="togglePairCode"
      >
        {{
          $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.BACK_TO_QR')
        }}
      </button>
    </div>

    <!-- QR code mode -->
    <div v-else class="flex flex-wrap flex-col mx-0">
      <h2 class="text-lg font-medium mb-4 text-n-slate-12">
        {{
          $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.SCAN_QR_TITLE')
        }}
      </h2>
      <div v-if="qrCode" class="mb-4 flex justify-center">
        <img
          :src="qrCode"
          :alt="
            $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.QR_ALT')
          "
          class="border border-n-weak rounded-xl p-2"
        />
      </div>
      <div v-else class="mb-4 text-sm text-n-slate-11">
        {{
          $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.WAITING_FOR_QR')
        }}
      </div>
      <button
        class="text-sm text-n-brand mb-4 cursor-pointer text-left"
        @click="togglePairCode"
      >
        {{
          $t('INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.USE_PAIR_CODE')
        }}
      </button>

      <div class="mt-6 border-t border-n-weak pt-6">
        <h3 class="text-sm font-medium mb-2 text-n-slate-12">
          {{
            $t(
              'INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.CONNECT_SECTION'
            )
          }}
        </h3>
        <NextButton
          solid
          blue
          :label="
            $t(
              'INBOX_MGMT.ADD.WAPI_WHATSAPP.ONBOARDING.CONNECT_BUTTON'
            )
          "
          :is-loading="isConnecting"
          @click="connectDevice"
        />
      </div>
    </div>
  </template>
</template>
