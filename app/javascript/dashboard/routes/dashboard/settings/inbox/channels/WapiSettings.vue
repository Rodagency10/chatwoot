<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import wapiChannel from 'dashboard/api/channel/wapiChannel';

const I18N = 'INBOX_MGMT.WAPI_SETTINGS';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

const deviceInfo = ref(null);
const isLoading = ref(false);
const isReconnecting = ref(false);
const isLoggingOut = ref(false);
const pollingInterval = ref(null);

const isWapiInbox = computed(() => {
  return !!props.inbox.additional_attributes?.wapi_device_id;
});

const statusLabel = computed(() => {
  if (!deviceInfo.value) return t(`${I18N}.STATUS_UNKNOWN`);
  return deviceInfo.value.is_connected
    ? t(`${I18N}.STATUS_CONNECTED`)
    : t(`${I18N}.STATUS_DISCONNECTED`);
});

const statusClass = computed(() => {
  if (!deviceInfo.value) return 'text-n-slate-11';
  return deviceInfo.value.is_connected ? 'text-n-teal-11' : 'text-n-ruby-11';
});

const fetchDeviceInfo = async () => {
  if (!isWapiInbox.value) return;
  try {
    const response = await wapiChannel.getDeviceInfo(props.inbox.id);
    deviceInfo.value = response.data;
  } catch {
    // Silently fail for polling
  }
};

const handleReconnect = async () => {
  isReconnecting.value = true;
  try {
    await wapiChannel.reconnect(props.inbox.id);
    useAlert(t(`${I18N}.RECONNECT_SUCCESS`));
    await fetchDeviceInfo();
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.RECONNECT_ERROR`));
  } finally {
    isReconnecting.value = false;
  }
};

const handleLogout = async () => {
  isLoggingOut.value = true;
  try {
    await wapiChannel.logout(props.inbox.id);
    useAlert(t(`${I18N}.LOGOUT_SUCCESS`));
    await fetchDeviceInfo();
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.LOGOUT_ERROR`));
  } finally {
    isLoggingOut.value = false;
  }
};

onMounted(() => {
  fetchDeviceInfo();
  pollingInterval.value = setInterval(fetchDeviceInfo, 30000);
});

onUnmounted(() => {
  if (pollingInterval.value) clearInterval(pollingInterval.value);
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
          v-if="deviceInfo.phone_number"
          class="flex items-center justify-between"
        >
          <span class="text-sm font-medium text-n-slate-11">
            {{ $t(`${I18N}.PHONE_NUMBER`) }}
          </span>
          <span class="text-sm font-mono text-n-slate-12">
            {{ deviceInfo.phone_number }}
          </span>
        </div>
        <div v-if="deviceInfo.jid" class="flex items-center justify-between">
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
      <div v-else class="text-sm text-n-slate-11">
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
          :is-loading="isReconnecting"
          @click="handleReconnect"
        />
        <NextButton
          :label="$t(`${I18N}.LOGOUT_BUTTON`)"
          :is-loading="isLoggingOut"
          color-scheme="alert"
          @click="handleLogout"
        />
      </div>
    </SettingsFieldSection>
  </div>
</template>
