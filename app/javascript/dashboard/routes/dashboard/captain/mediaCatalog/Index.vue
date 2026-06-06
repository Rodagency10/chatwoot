<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAlert } from 'dashboard/composables';
import { debounce } from '@chatwoot/utils';

import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import MediaAssetCard from 'dashboard/components-next/captain/assistant/MediaAssetCard.vue';
import CreateMediaAssetDialog from 'dashboard/components-next/captain/pageComponents/mediaAsset/CreateMediaAssetDialog.vue';

const route = useRoute();
const store = useStore();
const { t } = useI18n();
const { checkPermissions } = usePolicy();
const { showAlert } = useAlert();

const uiFlags = useMapGetter('captainMediaAssets/getUIFlags');
const mediaAssets = useMapGetter('captainMediaAssets/getRecords');
const mediaAssetsMeta = useMapGetter('captainMediaAssets/getMeta');

const searchQuery = ref('');
const showFormDialog = ref(false);
const editingAsset = ref(null);
const formDialogRef = ref(null);

const selectedAssistantId = computed(() => Number(route.params.assistantId));
const isFetching = computed(() => uiFlags.value.fetchingList);
const canManage = computed(() => checkPermissions(['administrator']));

const fetchMediaAssets = async (page = 1) => {
  await store.dispatch('captainMediaAssets/get', {
    page,
    assistantId: selectedAssistantId.value,
    searchKey: searchQuery.value,
  });
};

const debouncedSearch = debounce(() => fetchMediaAssets(1), 300);

watch(
  () => route.params.assistantId,
  () => fetchMediaAssets(1),
  { immediate: true }
);

const onPageChange = page => fetchMediaAssets(page);

const openCreateDialog = () => {
  editingAsset.value = null;
  showFormDialog.value = true;
  nextTick(() => formDialogRef.value?.dialogRef?.open());
};

const openEditDialog = id => {
  editingAsset.value = mediaAssets.value.find(asset => asset.id === id) || null;
  showFormDialog.value = true;
  nextTick(() => formDialogRef.value?.dialogRef?.open());
};

const closeFormDialog = () => {
  showFormDialog.value = false;
  editingAsset.value = null;
};

const handleFormSuccess = () => {
  closeFormDialog();
  fetchMediaAssets(mediaAssetsMeta.value?.page || 1);
};

const handleDelete = async id => {
  try {
    await store.dispatch('captainMediaAssets/delete', id);
    showAlert({ message: t('CAPTAIN.MEDIA_CATALOG.DELETE.SUCCESS') });
    await fetchMediaAssets(mediaAssetsMeta.value?.page || 1);
  } catch {
    showAlert({ message: t('CAPTAIN.MEDIA_CATALOG.DELETE.ERROR') });
  }
};
</script>

<template>
  <PageLayout
    :header-title="t('CAPTAIN.MEDIA_CATALOG.HEADER')"
    :button-label="t('CAPTAIN.MEDIA_CATALOG.ADD_NEW')"
    :button-policy="['administrator']"
    :is-fetching="isFetching"
    :total-count="mediaAssetsMeta.totalCount"
    :current-page="mediaAssetsMeta.page"
    :items-per-page="24"
    :show-pagination-footer="!isFetching && mediaAssets.length > 0"
    :is-empty="!mediaAssets.length"
    @update:current-page="onPageChange"
    @click="openCreateDialog"
  >
    <template #search>
      <Input
        v-model="searchQuery"
        :placeholder="t('CAPTAIN.MEDIA_CATALOG.SEARCH_PLACEHOLDER')"
        @input="debouncedSearch"
      />
    </template>

    <template #emptyState>
      <div class="flex flex-col items-center gap-2 py-16 text-center">
        <p class="text-base font-medium text-n-slate-12">
          {{ t('CAPTAIN.MEDIA_CATALOG.EMPTY_STATE.TITLE') }}
        </p>
        <p class="max-w-md text-sm text-n-slate-11">
          {{ t('CAPTAIN.MEDIA_CATALOG.EMPTY_STATE.DESCRIPTION') }}
        </p>
      </div>
    </template>

    <div class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
      <MediaAssetCard
        v-for="asset in mediaAssets"
        :id="asset.id"
        :key="asset.id"
        :name="asset.name"
        :thumb-url="asset.thumbUrl"
        :price-formatted="asset.priceFormatted"
        :tags="asset.tags"
        :active="asset.active"
        :can-manage="canManage"
        @edit="openEditDialog"
        @delete="handleDelete"
      />
    </div>

    <CreateMediaAssetDialog
      v-if="showFormDialog"
      ref="formDialogRef"
      :assistant-id="selectedAssistantId"
      :asset="editingAsset"
      @close="closeFormDialog"
      @success="handleFormSuccess"
    />
  </PageLayout>
</template>
