<script setup>
import { computed } from 'vue';
import { useToggle } from '@vueuse/core';
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
  imageCount: { type: Number, default: 0 },
  canManage: { type: Boolean, default: false },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();
const [showActionsDropdown, toggleDropdown] = useToggle();

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
  toggleDropdown(false);
  if (action === 'edit') emit('edit', props.id);
  if (action === 'delete') emit('delete', props.id);
};
</script>

<template>
  <CardLayout>
    <div class="flex flex-col gap-3">
      <div class="relative flex h-40 items-center justify-center overflow-hidden rounded-lg bg-n-alpha-1">
        <img
          v-if="thumbUrl"
          :src="thumbUrl"
          :alt="name"
          class="h-full w-full object-cover"
        />
        <span v-else class="text-sm text-n-slate-10">
          {{ t('CAPTAIN.MEDIA_CATALOG.CARD.NO_IMAGE') }}
        </span>

        <span
          v-if="imageCount > 1"
          class="absolute top-2 left-2 rounded-md bg-n-solid-3 px-2 py-0.5 text-xs text-n-slate-11"
        >
          {{ t('CAPTAIN.MEDIA_CATALOG.CARD.IMAGE_COUNT', { count: imageCount }) }}
        </span>

        <span
          v-if="!active"
          class="absolute top-2 right-2 rounded-md bg-n-solid-3 px-2 py-0.5 text-xs text-n-slate-11"
        >
          {{ t('CAPTAIN.MEDIA_CATALOG.CARD.INACTIVE') }}
        </span>
      </div>

      <div class="flex items-start justify-between gap-2">
        <div class="flex min-w-0 flex-1 flex-col gap-1">
          <h3 class="line-clamp-2 text-sm font-medium text-n-slate-12">
            {{ name }}
          </h3>
          <p v-if="priceFormatted" class="text-sm text-n-slate-11">
            {{ priceFormatted }}
          </p>
          <p v-if="tags.length" class="line-clamp-1 text-xs text-n-slate-10">
            {{ tags.join(', ') }}
          </p>
        </div>

        <div
          v-if="canManage"
          v-on-clickaway="() => toggleDropdown(false)"
          class="group relative flex shrink-0 items-center"
        >
          <Button
            icon="i-lucide-ellipsis-vertical"
            color="slate"
            size="xs"
            class="rounded-md group-hover:bg-n-alpha-2"
            @click="toggleDropdown()"
          />
          <DropdownMenu
            v-if="showActionsDropdown"
            :menu-items="menuItems"
            class="top-full z-10 mt-1 ltr:right-0 rtl:left-0"
            @action="handleAction"
          />
        </div>
      </div>
    </div>
  </CardLayout>
</template>
