<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import WapiConnectionFlow from './WapiConnectionFlow.vue';
import wapiChannel from 'dashboard/api/channel/wapiChannel';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const I18N = 'INBOX_MGMT.WAPI_SETTINGS';

const { t } = useI18n();

const deviceInfo = ref(null);
const isLoggingOut = ref(false);
const isLoadingDeviceInfo = ref(true);
const showLoginFlow = ref(false);
const logoutDialogRef = ref(null);
const connectionFlowRef = ref(null);
const pollingInterval = ref(null);

const isWapiInbox = computed(() => {
  return !!props.inbox.additional_attributes?.wapi_device_id;
});

const isConnected = computed(() => deviceInfo.value?.is_connected === true);

const statusLabel = computed(() => {
  if (!deviceInfo.value) return t(`${I18N}.STATUS_UNKNOWN`);
  return isConnected.value
    ? t(`${I18N}.STATUS_CONNECTED`)
    : t(`${I18N}.STATUS_DISCONNECTED`);
});

const statusClass = computed(() => {
  if (!deviceInfo.value) return 'text-n-slate-11';
  return isConnected.value ? 'text-n-teal-11' : 'text-n-ruby-11';
});

const canReconnect = computed(
  () => !isLoadingDeviceInfo.value && deviceInfo.value && !isConnected.value
);

const canLogout = computed(
  () => !isLoadingDeviceInfo.value && deviceInfo.value && isConnected.value
);

const fetchDeviceInfo = async () => {
  if (!isWapiInbox.value) return;

  isLoadingDeviceInfo.value = true;
  try {
    const response = await wapiChannel.getDeviceInfo(props.inbox.id);
    deviceInfo.value = response.data;
  } catch {
    deviceInfo.value = null;
  } finally {
    isLoadingDeviceInfo.value = false;
  }
};

const openLogoutDialog = () => {
  logoutDialogRef.value?.open();
};

const handleLogoutConfirm = async () => {
  logoutDialogRef.value?.close();
  isLoggingOut.value = true;
  try {
    await wapiChannel.logout(props.inbox.id);
    showLoginFlow.value = false;
    connectionFlowRef.value?.stopPolling();
    useAlert(t(`${I18N}.LOGOUT_SUCCESS`));
    await fetchDeviceInfo();
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.LOGOUT_ERROR`));
  } finally {
    isLoggingOut.value = false;
  }
};

const handleReconnectClick = () => {
  showLoginFlow.value = true;
};

const handleReconnected = async () => {
  showLoginFlow.value = false;
  connectionFlowRef.value?.stopPolling();
  useAlert(t(`${I18N}.CONNECTED_SUCCESS`));
  await fetchDeviceInfo();
};

onMounted(() => {
  fetchDeviceInfo();
  pollingInterval.value = setInterval(fetchDeviceInfo, 30000);
});

onUnmounted(() => {
  if (pollingInterval.value) clearInterval(pollingInterval.value);
  connectionFlowRef.value?.stopPolling();
});
</script>

<template>
  <div v-if="isWapiInbox" class="space-y-4">
    <SettingsFieldSection
      :label="$t(`${I18N}.TITLE`)"
      :help-text="$t(`${I18N}.DESC`)"
    >
      <div
        v-if="deviceInfo"
        class="rounded-xl border border-n-weak bg-n-alpha-2 p-4 space-y-3"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t(`${I18N}.CONNECTION_STATUS`) }}
          </span>
          <span class="text-sm font-semibold" :class="statusClass">
            {{ statusLabel }}
          </span>
        </div>
        <div
          v-if="isConnected && deviceInfo.phone_number"
          class="flex items-center justify-between"
        >
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t(`${I18N}.PHONE_NUMBER`) }}
          </span>
          <span class="text-sm font-mono text-n-slate-12">
            {{ deviceInfo.phone_number }}
          </span>
        </div>
        <div
          v-if="isConnected && deviceInfo.jid"
          class="flex items-center justify-between"
        >
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t(`${I18N}.JID`) }}
          </span>
          <span class="text-sm font-mono text-n-slate-12">
            {{ deviceInfo.jid }}
          </span>
        </div>
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t(`${I18N}.DEVICE_ID`) }}
          </span>
          <span class="text-sm font-mono text-n-slate-12">
            {{ deviceInfo.device_id }}
          </span>
        </div>
      </div>
      <div v-else-if="isLoadingDeviceInfo" class="text-sm text-n-slate-11">
        {{ $t(`${I18N}.LOADING`) }}
      </div>
    </SettingsFieldSection>

    <SettingsFieldSection
      :label="$t(`${I18N}.ACTIONS_TITLE`)"
      :help-text="$t(`${I18N}.ACTIONS_DESC`)"
    >
      <div class="flex gap-3">
        <NextButton
          :label="$t(`${I18N}.RECONNECT_BUTTON`)"
          :disabled="!canReconnect"
          @click="handleReconnectClick"
        />
        <NextButton
          :label="$t(`${I18N}.LOGOUT_BUTTON`)"
          :is-loading="isLoggingOut"
          :disabled="!canLogout"
          color="ruby"
          @click="openLogoutDialog"
        />
      </div>
    </SettingsFieldSection>

    <SettingsFieldSection
      v-if="showLoginFlow"
      :label="$t(`${I18N}.RELOGIN_TITLE`)"
      :help-text="$t(`${I18N}.RELOGIN_DESC`)"
    >
      <WapiConnectionFlow
        ref="connectionFlowRef"
        :inbox-id="inbox.id"
        connect-error-key="INBOX_MGMT.WAPI_SETTINGS.RECONNECT_ERROR"
        @connected="handleReconnected"
      />
    </SettingsFieldSection>

    <Dialog
      ref="logoutDialogRef"
      type="alert"
      :title="$t(`${I18N}.LOGOUT_CONFIRM_TITLE`)"
      :description="$t(`${I18N}.LOGOUT_CONFIRM_DESCRIPTION`)"
      :confirm-button-label="$t(`${I18N}.LOGOUT_CONFIRM_BUTTON`)"
      @confirm="handleLogoutConfirm"
    />
  </div>
</template>
