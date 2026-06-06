<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';
import WapiConnectionFlow from './WapiConnectionFlow.vue';
import wapiChannel from 'dashboard/api/channel/wapiChannel';

const I18N = 'INBOX_MGMT.ADD.WAPI_INBOX';

const { t } = useI18n();
const router = useRouter();

const step = ref('form');
const inboxName = ref('');
const inboxId = ref(null);
const deviceCreated = ref(false);
const isLoading = ref(false);

const validationRules = { inboxName: { required } };
const v$ = useVuelidate(validationRules, { inboxName });

const createInbox = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  isLoading.value = true;
  try {
    const response = await wapiChannel.createInbox(inboxName.value.trim());
    inboxId.value = response.data.inbox_id;
    deviceCreated.value = true;
    step.value = 'qr';
  } catch (error) {
    useAlert(error.response?.data?.error || t(`${I18N}.ERROR_CREATE_INBOX`));
  } finally {
    isLoading.value = false;
  }
};

const handleConnected = () => {
  useAlert(t(`${I18N}.CONNECTED_SUCCESS`));
  router.replace({
    name: 'settings_inboxes_add_agents',
    params: { page: 'new', inbox_id: inboxId.value },
  });
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="$t(`${I18N}.TITLE`)"
      :header-content="$t(`${I18N}.DESC`)"
    />

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

    <WapiConnectionFlow
      v-if="step === 'qr' && deviceCreated && inboxId"
      :inbox-id="inboxId"
      @connected="handleConnected"
    />
  </div>
</template>
