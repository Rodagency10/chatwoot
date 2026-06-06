<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  id: { type: Number, required: true },
  name: { type: String, default: '' },
  thumbUrl: { type: String, default: '' },
  priceFormatted: { type: String, default: '' },
  tags: { type: Array, default: () => [] },
  active: { type: Boolean, default: true },
  canManage: { type: Boolean, default: false },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();

const menuItems = computed(() => [
  {
    label: t('CAPTAIN.MEDIA_CATALOG.CARD.EDIT'),
    action: 'edit',
    icon: 'i-lucide-pencil',
  },
  {
    label: t('CAPTAIN.MEDIA_CATALOG.CARD.DELETE'),
    action: 'delete',
    icon: 'i-lucide-trash-2',
  },
]);

const handleAction = ({ action }) => {
  if (action === 'edit') emit('edit', props.id);
  if (action === 'delete') emit('delete', props.id);
};
</script>

<template>
  <CardLayout>
    <div class="flex flex-col gap-3">
      <div
        class="relative flex h-40 items-center justify-center overflow-hidden rounded-lg bg-n-alpha-1"
      >
        <img
          v-if="thumbUrl"
          :src="thumbUrl"
          :alt="name"
          class="h-full w-full object-cover"
        />
        <span v-else class="text-n-slate-10 text-sm">
          {{ t('CAPTAIN.MEDIA_CATALOG.CARD.NO_IMAGE') }}
        </span>
        <span
          v-if="!active"
          class="absolute top-2 right-2 rounded-md bg-n-solid-3 px-2 py-0.5 text-xs text-n-slate-11"
        >
          {{ t('CAPTAIN.MEDIA_CATALOG.CARD.INACTIVE') }}
        </span>
      </div>

      <div class="flex flex-col gap-1">
        <h3 class="text-sm font-medium text-n-slate-12 line-clamp-2">
          {{ name }}
        </h3>
        <p v-if="priceFormatted" class="text-sm text-n-slate-11">
          {{ priceFormatted }}
        </p>
        <p v-if="tags.length" class="text-xs text-n-slate-10 line-clamp-1">
          {{ tags.join(', ') }}
        </p>
      </div>

      <div v-if="canManage" class="flex justify-end">
        <DropdownMenu :menu-items="menuItems" @action="handleAction">
          <Button
            icon="i-lucide-ellipsis-vertical"
            variant="ghost"
            color="slate"
            size="sm"
          />
        </DropdownMenu>
      </div>
    </div>
  </CardLayout>
</template>
