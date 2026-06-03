/* global axios */
import ApiClient from '../ApiClient';

class WapiChannel extends ApiClient {
  constructor() {
    super('whatsapp/wapi', { accountScoped: true });
  }

  createDevice(inboxId) {
    return axios.post(`${this.baseUrl()}/whatsapp/wapi/create_device`, { inbox_id: inboxId });
  }

  getQr(inboxId) {
    return axios.get(`${this.baseUrl()}/whatsapp/wapi/qr`, { params: { inbox_id: inboxId } });
  }

  loginWithCode(inboxId, phone) {
    return axios.post(`${this.baseUrl()}/whatsapp/wapi/login_with_code`, { inbox_id: inboxId, phone });
  }

  getStatus(inboxId) {
    return axios.get(`${this.baseUrl()}/whatsapp/wapi/status`, { params: { inbox_id: inboxId } });
  }

  connectDevice(inboxId, apiToken) {
    return axios.post(`${this.baseUrl()}/whatsapp/wapi/connect`, { inbox_id: inboxId, api_token: apiToken });
  }
}

export default new WapiChannel();
