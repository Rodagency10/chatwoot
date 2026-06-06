/* global axios */
import ApiClient from '../ApiClient';

class CaptainMediaAsset extends ApiClient {
  constructor() {
    super('captain/media_assets', { accountScoped: true });
  }

  get({ page = 1, searchKey, assistantId, activeOnly } = {}) {
    return axios.get(this.url, {
      params: {
        page,
        search_key: searchKey,
        assistant_id: assistantId,
        active_only: activeOnly,
      },
    });
  }

  create(formData) {
    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  update(id, formData) {
    return axios.patch(`${this.url}/${id}`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new CaptainMediaAsset();
