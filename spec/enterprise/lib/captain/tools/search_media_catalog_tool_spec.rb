require 'rails_helper'

RSpec.describe Captain::Tools::SearchMediaCatalogTool, type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:tool) { described_class.new(assistant) }
  let!(:matching_asset) do
    create(:captain_media_asset, assistant: assistant, account: account, name: 'Gold wedding band', tags: %w[gold wedding])
  end

  before do
    create(:captain_media_asset, assistant: assistant, account: account, name: 'Silver chain', tags: %w[silver])
  end

  describe '#perform' do
    it 'returns matching catalog assets' do
      result = tool.perform(Struct.new(:state).new({}), query: 'gold wedding')
      expect(result).to include("ID: #{matching_asset.id}")
      expect(result).to include('Gold wedding band')
      expect(result).not_to include('Silver chain')
    end

    it 'returns a not found message when nothing matches' do
      result = tool.perform(Struct.new(:state).new({}), query: 'diamond')
      expect(result).to eq('No matching catalog items found for: diamond')
    end
  end
end
