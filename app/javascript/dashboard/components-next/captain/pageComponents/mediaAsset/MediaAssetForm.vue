<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  assistantId: { type: Number, required: true },
  asset: { type: Object, default: null },
});

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();
const fileInputRef = ref(null);

const state = reactive({
  name: props.asset?.name || '',
  sku: props.asset?.sku || '',
  price: props.asset?.priceCents ? (props.asset.priceCents / 100).toString() : '',
  currency: props.asset?.currency || 'EUR',
  description: props.asset?.description || '',
  tags: props.asset?.tags?.join(', ') || '',
  active: props.asset?.active ?? true,
  imageFile: null,
});

const isEditing = computed(() => !!props.asset?.id);

const handleFileChange = event => {
  const [file] = event.target.files || [];
  state.imageFile = file || null;
  if (file && !state.name) {
    state.name = file.name.replace(/\.[^.]+$/, '');
  }
};

const prepareFormData = () => {
  const formData = new FormData();
  formData.append('media_asset[assistant_id]', props.assistantId);
  formData.append('media_asset[name]', state.name);
  formData.append('media_asset[sku]', state.sku);
  formData.append('media_asset[currency]', state.currency);
  formData.append('media_asset[description]', state.description);
  formData.append('media_asset[active]', state.active);

  if (state.price) {
    const priceCents = Math.round(parseFloat(state.price) * 100);
    formData.append('media_asset[price_cents]', priceCents);
  }

  state.tags
    .split(',')
    .map(tag => tag.trim())
    .filter(Boolean)
    .forEach(tag => formData.append('media_asset[tags][]', tag));

  if (state.imageFile) {
    formData.append('media_asset[image]', state.imageFile);
  }

  return formData;
};

const handleSubmit = () => {
  if (!state.name.trim()) return;
  if (!isEditing.value && !state.imageFile) return;

  emit('submit', prepareFormData());
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.name"
      :label="t('CAPTAIN.MEDIA_CATALOG.FORM.NAME')"
      :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.NAME_PLACEHOLDER')"
    />

    <div class="grid grid-cols-2 gap-3">
      <Input
        v-model="state.price"
        type="number"
        step="0.01"
        min="0"
        :label="t('CAPTAIN.MEDIA_CATALOG.FORM.PRICE')"
        :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.PRICE_PLACEHOLDER')"
      />
      <Input
        v-model="state.currency"
        :label="t('CAPTAIN.MEDIA_CATALOG.FORM.CURRENCY')"
      />
    </div>

    <Input
      v-model="state.sku"
      :label="t('CAPTAIN.MEDIA_CATALOG.FORM.SKU')"
      :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.SKU_PLACEHOLDER')"
    />

    <Input
      v-model="state.tags"
      :label="t('CAPTAIN.MEDIA_CATALOG.FORM.TAGS')"
      :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.TAGS_PLACEHOLDER')"
    />

    <TextArea
      v-model="state.description"
      :label="t('CAPTAIN.MEDIA_CATALOG.FORM.DESCRIPTION')"
      :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.DESCRIPTION_PLACEHOLDER')"
    />

    <div class="flex flex-col gap-2">
      <span class="text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE') }}
      </span>
      <input
        ref="fileInputRef"
        type="file"
        accept="image/*"
        class="text-sm text-n-slate-11"
        @change="handleFileChange"
      />
    </div>

    <div class="flex items-center justify-between">
      <span class="text-sm text-n-slate-12">
        {{ t('CAPTAIN.MEDIA_CATALOG.FORM.ACTIVE') }}
      </span>
      <Switch v-model="state.active" />
    </div>

    <div class="flex justify-end gap-2">
      <Button
        variant="ghost"
        color="slate"
        :label="t('CAPTAIN.FORM.CANCEL')"
        @click="emit('cancel')"
      />
      <Button
        type="submit"
        :label="isEditing ? t('CAPTAIN.FORM.EDIT') : t('CAPTAIN.FORM.CREATE')"
      />
    </div>
  </form>
</template>
