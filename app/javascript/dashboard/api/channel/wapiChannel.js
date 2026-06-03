/* global axios */
import ApiClient from '../ApiClient';

class WapiChannel extends ApiClient {
  constructor() {
    super('wapi', { accountScoped: true });
  }

  createInbox(name) {
    return axios.post(`${this.baseUrl()}/wapi/create_inbox`, { name });
  }

  getQr(inboxId) {
    return axios.get(`${this.baseUrl()}/wapi/qr`, {
      params: { inbox_id: inboxId },
    });
  }

  loginWithCode(inboxId, phone) {
    return axios.post(`${this.baseUrl()}/wapi/login_with_code`, {
      inbox_id: inboxId,
      phone,
    });
  }

  getStatus(inboxId) {
    return axios.get(`${this.baseUrl()}/wapi/status`, {
      params: { inbox_id: inboxId },
    });
  }

  connect(inboxId) {
    return axios.post(`${this.baseUrl()}/wapi/connect`, {
      inbox_id: inboxId,
    });
  }

  getDeviceInfo(inboxId) {
    return axios.get(`${this.baseUrl()}/wapi/device_info`, {
      params: { inbox_id: inboxId },
    });
  }

  reconnect(inboxId) {
    return axios.post(`${this.baseUrl()}/wapi/reconnect`, {
      inbox_id: inboxId,
    });
  }

  logout(inboxId) {
    return axios.post(`${this.baseUrl()}/wapi/logout`, {
      inbox_id: inboxId,
    });
  }
}

export default new WapiChannel();
