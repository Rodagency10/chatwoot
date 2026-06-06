import CaptainMediaAssetAPI from 'dashboard/api/captain/mediaAsset';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'CaptainMediaAsset',
  API: CaptainMediaAssetAPI,
  getters: {
    getRecords: state => state.records,
  },
});
