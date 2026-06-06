<script setup>
import { computed, ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import MediaAssetForm from './MediaAssetForm.vue';
import CaptainMediaAssetAPI from 'dashboard/api/captain/mediaAsset';

const props = defineProps({
  assistantId: { type: Number, required: true },
  asset: { type: Object, default: null },
});

const emit = defineEmits(['close', 'success']);

const { t } = useI18n();
const store = useStore();
const dialogRef = ref(null);

const isEditing = computed(() => !!props.asset?.id);
const dialogTitle = computed(() =>
  isEditing.value
    ? t('CAPTAIN.MEDIA_CATALOG.FORM.EDIT_TITLE')
    : t('CAPTAIN.MEDIA_CATALOG.FORM.CREATE_TITLE')
);

const handleSubmit = async formData => {
  try {
    if (isEditing.value) {
      await CaptainMediaAssetAPI.update(props.asset.id, formData);
      useAlert(t('CAPTAIN.MEDIA_CATALOG.UPDATE.SUCCESS'));
    } else {
      await store.dispatch('captainMediaAssets/create', formData);
      useAlert(t('CAPTAIN.MEDIA_CATALOG.CREATE.SUCCESS'));
    }
    emit('success');
    dialogRef.value.close();
  } catch (error) {
    const errorMessage =
      parseAPIErrorResponse(error) ||
      (isEditing.value
        ? t('CAPTAIN.MEDIA_CATALOG.UPDATE.ERROR')
        : t('CAPTAIN.MEDIA_CATALOG.CREATE.ERROR'));
    useAlert(errorMessage);
  }
};

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="dialogTitle"
    :show-confirm-button="false"
    :show-cancel-button="false"
    width="2xl"
    @close="emit('close')"
  >
    <MediaAssetForm
      :assistant-id="assistantId"
      :asset="asset"
      @submit="handleSubmit"
      @cancel="dialogRef?.close()"
    />
  </Dialog>
</template>
