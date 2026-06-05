<script setup>
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';
import Button from 'dashboard/components-next/button/Button.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import SettingsHeader from 'dashboard/components-next/captain/pageComponents/settings/SettingsHeader.vue';
import AssistantBasicSettingsForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantBasicSettingsForm.vue';
import AssistantSystemSettingsForm from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantSystemSettingsForm.vue';
import AssistantControlItems from 'dashboard/components-next/captain/pageComponents/assistant/settings/AssistantControlItems.vue';
import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import CaptainAutoResolveSettings from 'dashboard/routes/dashboard/settings/captain/components/CaptainAutoResolveSettings.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';

const TAB_KEYS = {
  GENERAL: 'general',
  BEHAVIOR: 'behavior',
  ACCOUNT: 'account',
  CONTROLS: 'controls',
  DANGER: 'danger',
};

const { t } = useI18n();
const { isCloudFeatureEnabled } = useAccount();
const { isAdmin } = useAdmin();

const isCaptainV2Enabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_V2)
);
const route = useRoute();
const router = useRouter();
const store = useStore();

const deleteAssistantDialog = ref(null);
const selectedTabKey = ref(TAB_KEYS.GENERAL);

const uiFlags = useMapGetter('captainAssistants/getUIFlags');
const assistants = useMapGetter('captainAssistants/getRecords');
const isFetching = computed(() => uiFlags.value.fetchingItem);
const assistantId = computed(() => Number(route.params.assistantId));
const assistant = computed(() =>
  store.getters['captainAssistants/getRecord'](assistantId.value)
);

const tabs = computed(() => {
  const items = [
    {
      key: TAB_KEYS.GENERAL,
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.GENERAL'),
    },
    {
      key: TAB_KEYS.BEHAVIOR,
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.BEHAVIOR'),
    },
  ];

  if (isAdmin.value) {
    items.push({
      key: TAB_KEYS.ACCOUNT,
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.ACCOUNT'),
    });
  }

  if (isCaptainV2Enabled.value) {
    items.push({
      key: TAB_KEYS.CONTROLS,
      label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.CONTROLS'),
    });
  }

  items.push({
    key: TAB_KEYS.DANGER,
    label: t('CAPTAIN.ASSISTANTS.SETTINGS.TABS.DANGER'),
  });

  return items;
});

const selectedTabIndex = computed(() => {
  const index = tabs.value.findIndex(tab => tab.key === selectedTabKey.value);
  return index === -1 ? 0 : index;
});

const controlItems = computed(() => {
  return [
    {
      name: t(
        'CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.GUARDRAILS.TITLE'
      ),
      description: t(
        'CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.GUARDRAILS.DESCRIPTION'
      ),
      routeName: 'captain_assistants_guardrails_index',
    },
    {
      name: t(
        'CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.RESPONSE_GUIDELINES.TITLE'
      ),
      description: t(
        'CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.OPTIONS.RESPONSE_GUIDELINES.DESCRIPTION'
      ),
      routeName: 'captain_assistants_guidelines_index',
    },
  ];
});

const handleTabChange = tab => {
  selectedTabKey.value = tab.key;
};

const handleSubmit = async updatedAssistant => {
  try {
    await store.dispatch('captainAssistants/update', {
      id: assistantId.value,
      ...updatedAssistant,
    });
    useAlert(t('CAPTAIN.ASSISTANTS.EDIT.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('CAPTAIN.ASSISTANTS.EDIT.ERROR_MESSAGE');
    useAlert(errorMessage);
  }
};

const handleDelete = () => {
  deleteAssistantDialog.value.dialogRef.open();
};

const handleDeleteSuccess = () => {
  const remainingAssistants = assistants.value.filter(
    a => a.id !== assistantId.value
  );

  if (remainingAssistants.length > 0) {
    const nextAssistant = remainingAssistants[0];
    router.push({
      name: 'captain_assistants_settings_index',
      params: {
        accountId: route.params.accountId,
        assistantId: nextAssistant.id,
      },
    });
  } else {
    router.push({
      name: 'captain_assistants_create_index',
      params: { accountId: route.params.accountId },
    });
  }
};
</script>

<template>
  <PageLayout
    :is-fetching="isFetching"
    :show-pagination-footer="false"
    :show-know-more="false"
    class="[&>header>div]:max-w-[80rem] [&>main>div]:max-w-[80rem]"
  >
    <template #body>
      <div class="flex flex-col gap-6 pb-8">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="selectedTabIndex"
          @tab-changed="handleTabChange"
        />

        <div
          v-if="selectedTabKey === TAB_KEYS.GENERAL"
          class="flex flex-col gap-6"
        >
          <SettingsHeader
            :heading="t('CAPTAIN.ASSISTANTS.SETTINGS.BASIC_SETTINGS.TITLE')"
            :description="
              t('CAPTAIN.ASSISTANTS.SETTINGS.BASIC_SETTINGS.DESCRIPTION')
            "
          />
          <AssistantBasicSettingsForm
            :assistant="assistant"
            @submit="handleSubmit"
          />
        </div>

        <div
          v-else-if="selectedTabKey === TAB_KEYS.BEHAVIOR"
          class="flex flex-col gap-6"
        >
          <SettingsHeader
            :heading="t('CAPTAIN.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.TITLE')"
            :description="
              t('CAPTAIN.ASSISTANTS.SETTINGS.SYSTEM_SETTINGS.DESCRIPTION')
            "
          />
          <AssistantSystemSettingsForm
            :assistant="assistant"
            @submit="handleSubmit"
          />
        </div>

        <div
          v-else-if="selectedTabKey === TAB_KEYS.ACCOUNT && isAdmin"
          class="flex flex-col gap-6"
        >
          <SettingsHeader
            :heading="t('CAPTAIN_SETTINGS.AUTO_RESOLVE.SECTION_TITLE')"
            :description="
              t('CAPTAIN_SETTINGS.AUTO_RESOLVE.SECTION_DESCRIPTION')
            "
          />
          <CaptainAutoResolveSettings />
        </div>

        <div
          v-else-if="selectedTabKey === TAB_KEYS.CONTROLS && isCaptainV2Enabled"
          class="flex flex-col gap-6"
        >
          <SettingsHeader
            :heading="t('CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.TITLE')"
            :description="
              t('CAPTAIN.ASSISTANTS.SETTINGS.CONTROL_ITEMS.DESCRIPTION')
            "
          />
          <div class="flex flex-col gap-6">
            <AssistantControlItems
              v-for="item in controlItems"
              :key="item.name"
              :control-item="item"
            />
          </div>
        </div>

        <div
          v-else-if="selectedTabKey === TAB_KEYS.DANGER"
          class="flex items-end justify-between w-full gap-4"
        >
          <div class="flex flex-col gap-2">
            <h6 class="text-n-slate-12 text-base font-medium">
              {{ t('CAPTAIN.ASSISTANTS.SETTINGS.DELETE.TITLE') }}
            </h6>
            <span class="text-n-slate-11 text-sm">
              {{ t('CAPTAIN.ASSISTANTS.SETTINGS.DELETE.DESCRIPTION') }}
            </span>
          </div>
          <div class="flex-shrink-0">
            <Button
              :label="
                t('CAPTAIN.ASSISTANTS.SETTINGS.DELETE.BUTTON_TEXT', {
                  assistantName: assistant.name,
                })
              "
              color="ruby"
              class="max-w-56 !w-fit"
              @click="handleDelete"
            />
          </div>
        </div>
      </div>
    </template>
    <DeleteDialog
      v-if="assistant"
      ref="deleteAssistantDialog"
      :entity="assistant"
      type="Assistants"
      translation-key="ASSISTANTS"
      @delete-success="handleDeleteSuccess"
    />
  </PageLayout>
</template>
