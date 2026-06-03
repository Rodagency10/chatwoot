import { vi } from 'vitest';
import { shallowMount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createRouter, createWebHistory } from 'vue-router';
import { createStore } from 'vuex';
import WapiWhatsapp from '../WapiWhatsapp.vue';
import wapiChannel from 'dashboard/api/channel/wapiChannel';

vi.mock('dashboard/api/channel/wapiChannel', () => ({
  default: {
    createDevice: vi.fn(),
    getQr: vi.fn(),
    loginWithCode: vi.fn(),
    getStatus: vi.fn(),
    connectDevice: vi.fn(),
  },
}));

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: {
    en: {
      WAPI: {
        ONBOARDING: {
          CREATE_INBOX_TITLE: 'Create WhatsApp Inbox',
          INBOX_NAME_LABEL: 'Inbox Name',
          INBOX_NAME_PLACEHOLDER: 'e.g. Support WhatsApp',
          INBOX_NAME_REQUIRED: 'Inbox name is required',
          CREATE_BUTTON: 'Create Inbox',
          CREATING_DEVICE: 'Creating device...',
          PLEASE_WAIT: 'Please wait',
          SCAN_QR_TITLE: 'Scan QR Code',
          QR_ALT: 'WhatsApp QR Code',
          WAITING_FOR_QR: 'Waiting for QR code...',
          USE_PAIR_CODE: 'Use pairing code instead',
          PAIR_CODE_TITLE: 'Pair with Phone Number',
          PHONE_LABEL: 'Phone Number',
          PHONE_PLACEHOLDER: 'e.g. 1234567890',
          GET_PAIR_CODE: 'Get Pairing Code',
          YOUR_CODE: 'Your pairing code:',
          BACK_TO_QR: 'Back to QR code',
          CONNECT_SECTION: 'Connect to Chatwoot',
          API_TOKEN_LABEL: 'Your Chatwoot API Token',
          API_TOKEN_PLACEHOLDER: 'Enter your profile API token',
          CONNECT_BUTTON: 'Connect',
          CONNECT_SUCCESS: 'Device connected successfully!',
          CONNECTED_SUCCESS: 'WhatsApp connected!',
          ERROR_CREATE_INBOX: 'Failed to create inbox',
          ERROR_CREATE_DEVICE: 'Failed to create device',
          ERROR_PAIR_CODE: 'Failed to get pairing code',
          ERROR_PAIR_CODE_NO_CODE: 'Pairing code not available',
          ERROR_CONNECT: 'Failed to connect device',
          PHONE_REQUIRED: 'Phone number is required',
          API_TOKEN_REQUIRED: 'API token is required',
        },
      },
    },
  },
});

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', name: 'settings_inboxes_add_agents' },
    {
      path: '/settings/inboxes/new/wapi_whatsapp',
      name: 'settings_inboxes_page_channel',
    },
  ],
});

function getStore() {
  return createStore({
    getters: {
      'auth/getCurrentUser': () => ({ id: 1, access_token: 'test-token' }),
    },
    actions: {
      'inboxes/createChannel': async () => ({ id: 1, name: 'Test WhatsApp' }),
    },
  });
}

function getWrapper(options = {}) {
  const store = options.store || getStore();
  return shallowMount(WapiWhatsapp, {
    global: {
      plugins: [i18n, router, store],
      stubs: {
        NextButton: {
          template: '<button :disabled="isLoading">{{ label }}</button>',
          props: ['label', 'isLoading'],
        },
      },
      mocks: {
        $t: key => key,
      },
    },
  });
}

async function createInboxAndWait(wrapper) {
  wrapper.vm.inboxName = 'Test WhatsApp';
  await wrapper.vm.createInbox();
  await wrapper.vm.$nextTick();
  await new Promise(resolve => {
    setTimeout(resolve, 0);
  });
}

describe('WapiWhatsapp.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('shows form step initially', () => {
    const wrapper = getWrapper();
    expect(wrapper.vm.step).toBe('form');
    expect(wrapper.vm.inboxId).toBeNull();
  });

  it('creates inbox and device when createInbox is called', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });
    wapiChannel.getStatus.mockResolvedValue({
      data: { success: true, status: 'disconnected' },
    });
    wapiChannel.getQr.mockResolvedValue({
      data: { success: true, qr: 'qr-data' },
    });

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    expect(wrapper.vm.inboxId).toBe(1);
    expect(wrapper.vm.step).toBe('qr');
    expect(wapiChannel.createDevice).toHaveBeenCalledWith(1);
  });

  it('shows QR section when device is created', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });
    wapiChannel.getStatus.mockResolvedValue({
      data: { success: true, status: 'disconnected' },
    });
    wapiChannel.getQr.mockResolvedValue({
      data: { success: true, qr: 'qr-data' },
    });

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    expect(wrapper.vm.deviceCreated).toBe(true);
    expect(wrapper.vm.showPairCode).toBe(false);
    expect(wrapper.vm.qrCode).toBe('qr-data');
  });

  it('toggles pair code view', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });
    wapiChannel.getStatus.mockResolvedValue({
      data: { success: true, status: 'disconnected' },
    });
    wapiChannel.getQr.mockResolvedValue({
      data: { success: true, qr: 'qr-data' },
    });

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    expect(wrapper.vm.showPairCode).toBe(false);
    wrapper.vm.togglePairCode();
    expect(wrapper.vm.showPairCode).toBe(true);
  });

  it('requests pairing code when phone is provided', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });
    wapiChannel.loginWithCode.mockResolvedValue({
      data: { success: true, data: { code: 'ABCD-1234' } },
    });

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    wrapper.vm.phoneForCode = '1234567890';
    await wrapper.vm.requestPairCode();

    expect(wapiChannel.loginWithCode).toHaveBeenCalledWith(1, '1234567890');
    expect(wrapper.vm.loginCode).toBe('ABCD-1234');
  });

  it('shows alert when phone is empty for pair code', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    wrapper.vm.phoneForCode = '';
    await wrapper.vm.requestPairCode();

    expect(wapiChannel.loginWithCode).not.toHaveBeenCalled();
  });

  it('connects device using current user access token', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });
    wapiChannel.connectDevice.mockResolvedValue({ data: { success: true } });

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    await wrapper.vm.connectDevice();

    expect(wapiChannel.connectDevice).toHaveBeenCalledWith(1, 'test-token');
  });

  it('starts polling for status after device creation', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });
    wapiChannel.getStatus.mockResolvedValue({
      data: { success: true, status: 'disconnected' },
    });
    wapiChannel.getQr.mockResolvedValue({
      data: { success: true, qr: 'qr-data' },
    });

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    expect(wrapper.vm.pollingInterval).not.toBeNull();
  });

  it('stops polling when component is unmounted', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });
    wapiChannel.getStatus.mockResolvedValue({
      data: { success: true, status: 'disconnected' },
    });

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    wrapper.unmount();
    expect(wrapper.vm.pollingInterval).toBeNull();
  });

  it('navigates to add agents when connected', async () => {
    wapiChannel.createDevice.mockResolvedValue({ data: { success: true } });
    wapiChannel.getStatus.mockResolvedValue({
      data: { success: true, status: 'connected' },
    });

    const routerPush = vi.spyOn(router, 'replace').mockResolvedValue();

    const wrapper = getWrapper();
    await createInboxAndWait(wrapper);

    expect(routerPush).toHaveBeenCalledWith({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: 1 },
    });
  });
});
