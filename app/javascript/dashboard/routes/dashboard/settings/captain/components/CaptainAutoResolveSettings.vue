<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DurationInput from 'next/input/DurationInput.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import { DURATION_UNITS } from 'dashboard/components-next/input/constants';

const MODE_OPTIONS = [
  { id: 'evaluated', name: 'evaluated' },
  { id: 'legacy', name: 'legacy' },
  { id: 'disabled', name: 'disabled' },
];

const { t } = useI18n();
const { currentAccount, updateAccount, isCloudFeatureEnabled } = useAccount();

const duration = ref(60);
const unit = ref(DURATION_UNITS.MINUTES);
const mode = ref(MODE_OPTIONS[0]);
const isSubmitting = ref(false);

const hasCaptainTasks = () =>
  isCloudFeatureEnabled('captain_tasks') ||
  currentAccount.value?.features?.captain_tasks;

const modeOptions = () => {
  const options = [
    {
      id: 'legacy',
      name: t('CAPTAIN_SETTINGS.AUTO_RESOLVE.MODE.LEGACY'),
    },
    {
      id: 'disabled',
      name: t('CAPTAIN_SETTINGS.AUTO_RESOLVE.MODE.DISABLED'),
    },
  ];

  if (hasCaptainTasks()) {
    options.unshift({
      id: 'evaluated',
      name: t('CAPTAIN_SETTINGS.AUTO_RESOLVE.MODE.EVALUATED'),
    });
  }

  return options;
};

const syncFromAccount = () => {
  const settings = currentAccount.value?.settings || {};
  const {
    captain_auto_resolve_mode: resolveMode,
    captain_auto_resolve_after_minutes: resolveMinutes,
  } = settings;

  const minutes = resolveMinutes ?? 60;
  duration.value = minutes;

  if (minutes % (24 * 60) === 0 && minutes >= 24 * 60) {
    unit.value = DURATION_UNITS.DAYS;
  } else if (minutes % 60 === 0 && minutes >= 60) {
    unit.value = DURATION_UNITS.HOURS;
  } else {
    unit.value = DURATION_UNITS.MINUTES;
  }

  const effectiveMode =
    resolveMode || (hasCaptainTasks() ? 'evaluated' : 'legacy');
  mode.value =
    modeOptions().find(option => option.id === effectiveMode) ||
    modeOptions()[0];
};

watch(currentAccount, syncFromAccount, { immediate: true, deep: true });

const updateAccountSettings = async settings => {
  try {
    isSubmitting.value = true;
    await updateAccount(settings, { silent: true });
    useAlert(t('CAPTAIN_SETTINGS.AUTO_RESOLVE.API.SUCCESS'));
  } catch {
    useAlert(t('CAPTAIN_SETTINGS.AUTO_RESOLVE.API.ERROR'));
  } finally {
    isSubmitting.value = false;
  }
};

const handleSubmit = async () => {
  if (mode.value?.id !== 'disabled' && duration.value < 5) {
    useAlert(t('CAPTAIN_SETTINGS.AUTO_RESOLVE.DURATION.ERROR'));
    return;
  }

  await updateAccountSettings({
    captain_auto_resolve_mode: mode.value?.id,
    captain_auto_resolve_after_minutes:
      mode.value?.id === 'disabled' ? null : duration.value,
  });
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2 divide-y divide-n-weak"
  >
    <div class="flex flex-col gap-4 px-5 py-4">
      <div class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN_SETTINGS.AUTO_RESOLVE.TITLE') }}
        </span>
        <span class="text-sm text-n-slate-11">
          {{ t('CAPTAIN_SETTINGS.AUTO_RESOLVE.DESCRIPTION') }}
        </span>
      </div>

      <WithLabel :label="t('CAPTAIN_SETTINGS.AUTO_RESOLVE.MODE.LABEL')">
        <SingleSelect
          v-model="mode"
          :options="modeOptions()"
          :placeholder="t('CAPTAIN_SETTINGS.AUTO_RESOLVE.MODE.PLACEHOLDER')"
        />
      </WithLabel>

      <WithLabel
        v-if="mode?.id !== 'disabled'"
        :label="t('CAPTAIN_SETTINGS.AUTO_RESOLVE.DURATION.LABEL')"
      >
        <DurationInput v-model="duration" v-model:unit="unit" :min="5" />
      </WithLabel>
    </div>

    <div class="flex justify-end px-5 py-4">
      <NextButton
        :label="t('CAPTAIN_SETTINGS.AUTO_RESOLVE.SAVE')"
        :is-loading="isSubmitting"
        @click="handleSubmit"
      />
    </div>
  </div>
</template>
