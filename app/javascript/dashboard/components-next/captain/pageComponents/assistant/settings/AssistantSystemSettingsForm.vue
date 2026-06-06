<script setup>
import { reactive, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { minLength } from '@vuelidate/validators';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAccount } from 'dashboard/composables/useAccount';

import Button from 'dashboard/components-next/button/Button.vue';
import Editor from 'dashboard/components-next/Editor/Editor.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import Switch from 'next/switch/Switch.vue';

const props = defineProps({
  assistant: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();
const { isCloudFeatureEnabled } = useAccount();

const isCaptainV2Enabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_V2)
);

const initialState = {
  handoffMessage: '',
  resolutionMessage: '',
  sendHandoffMessage: false,
  sendResolutionMessage: false,
  responseDelaySeconds: 0,
  keywordActivationEnabled: false,
  activationKeywords: [],
  activationLabel: 'keyword_match',
  activationMatchMode: 'word',
  instructions: '',
  temperature: 1,
};

const state = reactive({ ...initialState });

const validationRules = computed(() => ({
  handoffMessage: state.sendHandoffMessage ? { minLength: minLength(1) } : {},
  resolutionMessage: state.sendResolutionMessage
    ? { minLength: minLength(1) }
    : {},
  instructions: { minLength: minLength(1) },
}));

const v$ = useVuelidate(validationRules, state);

const getErrorMessage = field => {
  return v$.value[field].$error ? v$.value[field].$errors[0].$message : '';
};

const formErrors = computed(() => ({
  handoffMessage: getErrorMessage('handoffMessage'),
  resolutionMessage: getErrorMessage('resolutionMessage'),
  instructions: getErrorMessage('instructions'),
}));

const configFlagFromAssistant = (config, key) =>
  config[key] === undefined ? false : Boolean(config[key]);

const updateStateFromAssistant = assistant => {
  const { config = {} } = assistant;
  state.handoffMessage = config.handoff_message;
  state.resolutionMessage = config.resolution_message;
  state.sendHandoffMessage = configFlagFromAssistant(
    config,
    'send_handoff_message'
  );
  state.sendResolutionMessage = configFlagFromAssistant(
    config,
    'send_resolution_message'
  );
  state.responseDelaySeconds = Number(config.response_delay_seconds) || 0;
  state.keywordActivationEnabled = configFlagFromAssistant(
    config,
    'keyword_activation_enabled'
  );
  state.activationKeywords = [...(config.activation_keywords || [])];
  state.activationLabel = config.activation_label || 'keyword_match';
  state.activationMatchMode = config.activation_match_mode || 'word';
  state.instructions = config.instructions;
  state.temperature = config.temperature || 1;
};

const handleSystemMessagesUpdate = async () => {
  const validations = [];

  if (state.sendHandoffMessage) {
    validations.push(v$.value.handoffMessage.$validate());
  }
  if (state.sendResolutionMessage) {
    validations.push(v$.value.resolutionMessage.$validate());
  }

  if (!isCaptainV2Enabled.value) {
    validations.push(v$.value.instructions.$validate());
  }

  if (validations.length) {
    const result = await Promise.all(validations).then(results =>
      results.every(Boolean)
    );
    if (!result) return;
  }

  const payload = {
    config: {
      ...props.assistant.config,
      handoff_message: state.handoffMessage,
      resolution_message: state.resolutionMessage,
      send_handoff_message: state.sendHandoffMessage,
      send_resolution_message: state.sendResolutionMessage,
      response_delay_seconds: Math.min(
        300,
        Math.max(0, Number(state.responseDelaySeconds) || 0)
      ),
      keyword_activation_enabled: state.keywordActivationEnabled,
      activation_keywords: state.activationKeywords
        .map(keyword => keyword.trim())
        .filter(Boolean),
      activation_label: state.activationLabel.trim() || 'keyword_match',
      activation_match_mode: state.activationMatchMode,
      temperature: state.temperature || 1,
    },
  };

  if (!isCaptainV2Enabled.value) {
    payload.config.instructions = state.instructions;
  }

  emit('submit', payload);
};

watch(
  () => props.assistant,
  newAssistant => {
    if (newAssistant) updateStateFromAssistant(newAssistant);
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex flex-col gap-4">
      <div class="flex items-center justify-between gap-4">
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.FORM.SEND_HANDOFF_MESSAGE.LABEL') }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.FORM.SEND_HANDOFF_MESSAGE.DESCRIPTION') }}
          </span>
        </div>
        <Switch v-model="state.sendHandoffMessage" />
      </div>

      <Editor
        v-if="state.sendHandoffMessage"
        v-model="state.handoffMessage"
        :label="t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_MESSAGE.LABEL')"
        :placeholder="t('CAPTAIN.ASSISTANTS.FORM.HANDOFF_MESSAGE.PLACEHOLDER')"
        :message="formErrors.handoffMessage"
        :message-type="formErrors.handoffMessage ? 'error' : 'info'"
        class="z-0"
      />
    </div>

    <div class="flex flex-col gap-4">
      <div class="flex items-center justify-between gap-4">
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.FORM.SEND_RESOLUTION_MESSAGE.LABEL') }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{
              t('CAPTAIN.ASSISTANTS.FORM.SEND_RESOLUTION_MESSAGE.DESCRIPTION')
            }}
          </span>
        </div>
        <Switch v-model="state.sendResolutionMessage" />
      </div>

      <Editor
        v-if="state.sendResolutionMessage"
        v-model="state.resolutionMessage"
        :label="t('CAPTAIN.ASSISTANTS.FORM.RESOLUTION_MESSAGE.LABEL')"
        :placeholder="
          t('CAPTAIN.ASSISTANTS.FORM.RESOLUTION_MESSAGE.PLACEHOLDER')
        "
        :message="formErrors.resolutionMessage"
        :message-type="formErrors.resolutionMessage ? 'error' : 'info'"
        class="z-0"
      />
    </div>

    <div class="flex flex-col gap-4">
      <div class="flex items-center justify-between gap-4">
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.FORM.KEYWORD_ACTIVATION.LABEL') }}
          </span>
          <span class="text-sm text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.FORM.KEYWORD_ACTIVATION.DESCRIPTION') }}
          </span>
        </div>
        <Switch v-model="state.keywordActivationEnabled" />
      </div>

      <template v-if="state.keywordActivationEnabled">
        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.FORM.ACTIVATION_KEYWORDS.LABEL') }}
          </label>
          <div
            class="min-h-10 rounded-lg bg-n-alpha-black2 px-3 py-2 outline outline-1 outline-offset-[-1px] outline-n-weak transition-all duration-500 hover:outline-n-slate-6 focus-within:outline-n-brand"
          >
            <TagInput
              v-model="state.activationKeywords"
              :placeholder="
                t('CAPTAIN.ASSISTANTS.FORM.ACTIVATION_KEYWORDS.PLACEHOLDER')
              "
              allow-create
            />
          </div>
          <p class="text-sm text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.FORM.ACTIVATION_KEYWORDS.DESCRIPTION') }}
          </p>
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.FORM.ACTIVATION_LABEL.LABEL') }}
          </label>
          <input
            v-model="state.activationLabel"
            type="text"
            class="w-full max-w-xs rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
            :placeholder="
              t('CAPTAIN.ASSISTANTS.FORM.ACTIVATION_LABEL.PLACEHOLDER')
            "
          />
          <p class="text-sm text-n-slate-11">
            {{ t('CAPTAIN.ASSISTANTS.FORM.ACTIVATION_LABEL.DESCRIPTION') }}
          </p>
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-n-slate-12">
            {{ t('CAPTAIN.ASSISTANTS.FORM.ACTIVATION_MATCH_MODE.LABEL') }}
          </label>
          <select
            v-model="state.activationMatchMode"
            class="w-full max-w-xs rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
          >
            <option value="word">
              {{
                t('CAPTAIN.ASSISTANTS.FORM.ACTIVATION_MATCH_MODE.OPTIONS.WORD')
              }}
            </option>
            <option value="substring">
              {{
                t(
                  'CAPTAIN.ASSISTANTS.FORM.ACTIVATION_MATCH_MODE.OPTIONS.SUBSTRING'
                )
              }}
            </option>
          </select>
        </div>
      </template>
    </div>

    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.ASSISTANTS.FORM.RESPONSE_DELAY.LABEL') }}
        </label>
        <input
          v-model.number="state.responseDelaySeconds"
          type="number"
          min="0"
          max="300"
          step="1"
          class="w-full max-w-xs rounded-lg border border-n-weak bg-n-solid-2 px-3 py-2 text-sm text-n-slate-12"
        />
        <p class="text-sm text-n-slate-11">
          {{ t('CAPTAIN.ASSISTANTS.FORM.RESPONSE_DELAY.DESCRIPTION') }}
        </p>
      </div>
    </div>

    <Editor
      v-if="!isCaptainV2Enabled"
      v-model="state.instructions"
      :label="t('CAPTAIN.ASSISTANTS.FORM.INSTRUCTIONS.LABEL')"
      :placeholder="t('CAPTAIN.ASSISTANTS.FORM.INSTRUCTIONS.PLACEHOLDER')"
      :message="formErrors.instructions"
      :max-length="20000"
      :message-type="formErrors.instructions ? 'error' : 'info'"
      class="z-0"
    />

    <div class="flex flex-col gap-2">
      <label class="text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.ASSISTANTS.FORM.TEMPERATURE.LABEL') }}
      </label>
      <div class="flex items-center gap-4">
        <input
          v-model="state.temperature"
          type="range"
          min="0"
          max="1"
          step="0.1"
          class="w-full"
        />
        <span class="text-sm text-n-slate-12">{{ state.temperature }}</span>
      </div>
      <p class="text-sm text-n-slate-11 italic">
        {{ t('CAPTAIN.ASSISTANTS.FORM.TEMPERATURE.DESCRIPTION') }}
      </p>
    </div>

    <div>
      <Button
        :label="t('CAPTAIN.ASSISTANTS.FORM.UPDATE')"
        @click="handleSystemMessagesUpdate"
      />
    </div>
  </div>
</template>
