<script setup>
import { computed, onBeforeUnmount, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';

const props = defineProps({
  assistantId: { type: Number, required: true },
  asset: { type: Object, default: null },
});
const emit = defineEmits(['submit', 'cancel']);
const MAX_IMAGES = 10;
const MAX_FILE_BYTES = 10 * 1024 * 1024;

const { t } = useI18n();
const fileInputRef = ref(null);

const formState = {
  uiFlags: useMapGetter('captainMediaAssets/getUIFlags'),
};

const state = reactive({
  name: props.asset?.name || '',
  sku: props.asset?.sku || '',
  price: props.asset?.price_cents
    ? (props.asset.price_cents / 100).toString()
    : '',
  currency: props.asset?.currency || 'EUR',
  description: props.asset?.description || '',
  tags: [...(props.asset?.tags || [])],
  active: props.asset?.active ?? true,
  existingImages: (props.asset?.images || []).map(image => ({ ...image })),
  pendingImages: [],
  removedImageIds: [],
  primaryImageId: props.asset?.primary_image_id || null,
});

const isEditing = computed(() => !!props.asset?.id);
const isLoading = computed(
  () =>
    formState.uiFlags.value.creatingItem || formState.uiFlags.value.updatingItem
);

const currencyOptions = [
  { value: 'XOF', label: 'XOF' },
  { value: 'EUR', label: 'EUR' },
  { value: 'USD', label: 'USD' },
  { value: 'GBP', label: 'GBP' },
  { value: 'CAD', label: 'CAD' },
  { value: 'MAD', label: 'MAD' },
  { value: 'NGN', label: 'NGN' },
  { value: 'CHF', label: 'CHF' },
  { value: 'JPY', label: 'JPY' },
];

const visibleExistingImages = computed(() =>
  state.existingImages.filter(
    image => !state.removedImageIds.includes(image.id)
  )
);

const totalImageCount = computed(
  () => visibleExistingImages.value.length + state.pendingImages.length
);

const showImageError = ref(false);

const validationRules = {
  name: { required },
};

const v$ = useVuelidate(validationRules, state);

const formErrors = computed(() => ({
  name: v$.value.name.$error ? t('CAPTAIN.MEDIA_CATALOG.FORM.NAME.ERROR') : '',
  images: showImageError.value
    ? t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.ERROR')
    : '',
}));

const galleryItems = computed(() => {
  const existing = visibleExistingImages.value.map(image => ({
    key: `existing-${image.id}`,
    id: image.id,
    previewUrl: image.thumb_url || image.url,
    label: image.label || '',
    isPrimary: state.primaryImageId === image.id,
    isExisting: true,
  }));

  const pending = state.pendingImages.map(image => ({
    key: image.tempId,
    id: image.tempId,
    previewUrl: image.previewUrl,
    label: image.label,
    isPrimary: false,
    isExisting: false,
  }));

  return [...existing, ...pending];
});

watch(
  () => props.asset,
  asset => {
    if (!asset) return;

    state.name = asset.name || '';
    state.sku = asset.sku || '';
    state.price = asset.price_cents ? (asset.price_cents / 100).toString() : '';
    state.currency = asset.currency || 'EUR';
    state.description = asset.description || '';
    state.tags = [...(asset.tags || [])];
    state.active = asset.active ?? true;
    state.existingImages = (asset.images || []).map(image => ({ ...image }));
    state.pendingImages = [];
    state.removedImageIds = [];
    state.primaryImageId = asset.primary_image_id || null;
  }
);

onBeforeUnmount(() => {
  state.pendingImages.forEach(image => URL.revokeObjectURL(image.previewUrl));
});

const openFileDialog = () => {
  fileInputRef.value?.click();
};

const handleFileChange = event => {
  const files = Array.from(event.target.files || []);
  event.target.value = '';

  if (!files.length) return;

  if (totalImageCount.value + files.length > MAX_IMAGES) {
    useAlert(
      t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.LIMIT', { count: MAX_IMAGES })
    );
    return;
  }

  files.forEach(file => {
    if (!file.type.startsWith('image/')) {
      useAlert(t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.INVALID_TYPE'));
      return;
    }

    if (file.size > MAX_FILE_BYTES) {
      useAlert(t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.TOO_LARGE'));
      return;
    }

    state.pendingImages.push({
      tempId: `pending-${Date.now()}-${Math.random()}`,
      file,
      previewUrl: URL.createObjectURL(file),
      label: '',
    });
  });
};

const removeGalleryItem = item => {
  if (item.isExisting) {
    state.removedImageIds.push(item.id);
    if (state.primaryImageId === item.id) {
      state.primaryImageId = null;
    }
    return;
  }

  const pending = state.pendingImages.find(image => image.tempId === item.id);
  if (pending) {
    URL.revokeObjectURL(pending.previewUrl);
    state.pendingImages = state.pendingImages.filter(
      image => image.tempId !== item.id
    );
  }
};

const setPrimaryImage = item => {
  if (!item.isExisting) return;
  state.primaryImageId = item.id;
};

const updateExistingLabel = (imageId, label) => {
  const image = state.existingImages.find(img => img.id === imageId);
  if (image) image.label = label;
};

const updatePendingLabel = (tempId, label) => {
  const image = state.pendingImages.find(img => img.tempId === tempId);
  if (image) image.label = label;
};

const prepareFormData = () => {
  const formData = new FormData();
  formData.append('media_asset[assistant_id]', props.assistantId);
  formData.append('media_asset[name]', state.name.trim());
  formData.append('media_asset[sku]', state.sku);
  formData.append('media_asset[currency]', state.currency);
  formData.append('media_asset[description]', state.description);
  formData.append('media_asset[active]', state.active);

  if (state.price) {
    const priceCents = Math.round(parseFloat(state.price) * 100);
    formData.append('media_asset[price_cents]', priceCents);
  }

  state.tags
    .map(tag => tag.trim())
    .filter(Boolean)
    .forEach(tag => formData.append('media_asset[tags][]', tag));

  state.pendingImages.forEach(image => {
    formData.append('media_asset[new_images][]', image.file);
    formData.append('media_asset[image_labels][]', image.label || '');
  });

  state.removedImageIds.forEach(id => {
    formData.append('media_asset[removed_image_ids][]', id);
  });

  visibleExistingImages.value.forEach((image, index) => {
    formData.append('media_asset[image_updates][][id]', image.id);
    formData.append('media_asset[image_updates][][label]', image.label || '');
    formData.append('media_asset[image_updates][][position]', index);
  });

  if (state.primaryImageId) {
    formData.append('media_asset[primary_image_id]', state.primaryImageId);
  }

  return formData;
};

const handleSubmit = async () => {
  showImageError.value = totalImageCount.value === 0;

  const isFormValid = await v$.value.$validate();
  if (!isFormValid || showImageError.value) return;

  emit('submit', prepareFormData());
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.name"
      :label="t('CAPTAIN.MEDIA_CATALOG.FORM.NAME.LABEL')"
      :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.NAME.PLACEHOLDER')"
      :message="formErrors.name"
      :message-type="formErrors.name ? 'error' : 'info'"
    />

    <div class="grid grid-cols-2 gap-3">
      <Input
        v-model="state.price"
        type="number"
        step="0.01"
        min="0"
        :label="t('CAPTAIN.MEDIA_CATALOG.FORM.PRICE.LABEL')"
        :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.PRICE.PLACEHOLDER')"
      />
      <div class="flex flex-col gap-1">
        <label class="mb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.MEDIA_CATALOG.FORM.CURRENCY.LABEL') }}
        </label>
        <ComboBox
          v-model="state.currency"
          :options="currencyOptions"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>
    </div>

    <Input
      v-model="state.sku"
      :label="t('CAPTAIN.MEDIA_CATALOG.FORM.SKU.LABEL')"
      :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.SKU.PLACEHOLDER')"
    />

    <div class="flex flex-col gap-1">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAPTAIN.MEDIA_CATALOG.FORM.TAGS.LABEL') }}
      </label>
      <div
        class="min-h-10 rounded-lg bg-n-alpha-black2 px-3 py-2 outline outline-1 outline-offset-[-1px] outline-n-weak transition-all duration-500 hover:outline-n-slate-6 focus-within:outline-n-brand"
      >
        <TagInput
          v-model="state.tags"
          :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.TAGS.PLACEHOLDER')"
          allow-create
        />
      </div>
    </div>

    <TextArea
      v-model="state.description"
      :label="t('CAPTAIN.MEDIA_CATALOG.FORM.DESCRIPTION.LABEL')"
      :placeholder="t('CAPTAIN.MEDIA_CATALOG.FORM.DESCRIPTION.PLACEHOLDER')"
    />

    <div class="flex flex-col gap-2">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.LABEL') }}
        </span>
        <span class="text-xs text-n-slate-11">
          {{
            t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.COUNT', {
              count: totalImageCount,
              max: MAX_IMAGES,
            })
          }}
        </span>
      </div>

      <input
        ref="fileInputRef"
        type="file"
        accept="image/*"
        multiple
        class="hidden"
        @change="handleFileChange"
      />

      <Button
        type="button"
        :color="formErrors.images ? 'ruby' : 'slate'"
        :variant="formErrors.images ? 'outline' : 'solid'"
        class="!w-full !h-auto !justify-between !py-4"
        :disabled="totalImageCount >= MAX_IMAGES"
        @click="openFileDialog"
      >
        <template #default>
          <div class="flex items-center gap-2">
            <div
              class="flex h-10 w-10 items-center justify-center rounded-lg bg-n-slate-3"
            >
              <i class="i-lucide-images text-xl text-n-slate-11" />
            </div>
            <div class="flex flex-col items-start gap-1">
              <p class="m-0 text-sm font-medium text-n-slate-12">
                {{ t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.CHOOSE') }}
              </p>
              <p class="m-0 text-xs text-n-slate-11">
                {{ t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.HELP') }}
              </p>
            </div>
          </div>
          <i class="i-lucide-upload text-n-slate-11" />
        </template>
      </Button>

      <p v-if="formErrors.images" class="text-xs text-n-ruby-9">
        {{ formErrors.images }}
      </p>

      <div
        v-if="galleryItems.length"
        class="grid grid-cols-2 gap-3 md:grid-cols-3"
      >
        <div
          v-for="item in galleryItems"
          :key="item.key"
          class="relative flex flex-col gap-2 overflow-hidden rounded-lg border border-n-weak bg-n-alpha-1 p-2"
        >
          <div class="relative h-28 overflow-hidden rounded-md bg-n-solid-3">
            <img
              :src="item.previewUrl"
              :alt="state.name"
              class="h-full w-full object-cover"
            />
            <span
              v-if="item.isPrimary"
              class="absolute top-1 left-1 rounded-md bg-n-brand px-2 py-0.5 text-xs text-white"
            >
              {{ t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.PRIMARY') }}
            </span>
          </div>

          <Input
            :model-value="item.label"
            :placeholder="
              t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.LABEL_PLACEHOLDER')
            "
            @update:model-value="
              item.isExisting
                ? updateExistingLabel(item.id, $event)
                : updatePendingLabel(item.id, $event)
            "
          />

          <div class="flex gap-2">
            <Button
              v-if="item.isExisting && !item.isPrimary"
              type="button"
              size="xs"
              variant="ghost"
              color="slate"
              :label="t('CAPTAIN.MEDIA_CATALOG.FORM.IMAGE.SET_PRIMARY')"
              class="flex-1"
              @click="setPrimaryImage(item)"
            />
            <Button
              type="button"
              size="xs"
              variant="ghost"
              color="ruby"
              icon="i-lucide-trash-2"
              class="flex-1"
              @click="removeGalleryItem(item)"
            />
          </div>
        </div>
      </div>
    </div>

    <div class="flex items-center justify-between">
      <span class="text-sm text-n-slate-12">
        {{ t('CAPTAIN.MEDIA_CATALOG.FORM.ACTIVE') }}
      </span>
      <Switch v-model="state.active" />
    </div>

    <div class="flex w-full items-center justify-between gap-3">
      <Button
        type="button"
        variant="faded"
        color="slate"
        :label="t('CAPTAIN.FORM.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="emit('cancel')"
      />
      <Button
        type="submit"
        :label="isEditing ? t('CAPTAIN.FORM.EDIT') : t('CAPTAIN.FORM.CREATE')"
        class="w-full"
        :is-loading="isLoading"
        :disabled="isLoading"
      />
    </div>
  </form>
</template>
