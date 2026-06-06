require 'rails_helper'

RSpec.describe Api::V1::Accounts::Captain::MediaAssetsController, type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let!(:media_asset) { create(:captain_media_asset, assistant: assistant, account: account) }

  describe 'GET /api/v1/accounts/:account_id/captain/media_assets' do
    it 'returns media assets for the assistant' do
      get "/api/v1/accounts/#{account.id}/captain/media_assets",
          params: { assistant_id: assistant.id },
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].first['name']).to eq(media_asset.name)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/captain/media_assets/:id' do
    it 'deletes the media asset' do
      expect do
        delete "/api/v1/accounts/#{account.id}/captain/media_assets/#{media_asset.id}",
               headers: admin.create_new_auth_token,
               as: :json
      end.to change(Captain::MediaAsset, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
