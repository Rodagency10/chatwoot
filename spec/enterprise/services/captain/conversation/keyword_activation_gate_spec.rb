require 'rails_helper'

RSpec.describe Captain::Conversation::KeywordActivationGate do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account, status: :pending) }
  let(:assistant) do
    create(
      :captain_assistant,
      account: account,
      config: {
        'keyword_activation_enabled' => true,
        'activation_keywords' => %w[catalogue commande],
        'activation_label' => 'keyword_match',
        'activation_match_mode' => 'word'
      }
    )
  end

  describe '#evaluate' do
    it 'allows processing when keyword activation is disabled' do
      assistant.update!(config: { 'keyword_activation_enabled' => false })

      result = described_class.new(
        conversation: conversation,
        assistant: assistant,
        message_content: 'bonjour'
      ).evaluate

      expect(result).to eq(:allowed)
    end

    it 'blocks processing when enabled and the message does not match' do
      result = described_class.new(
        conversation: conversation,
        assistant: assistant,
        message_content: 'bonjour'
      ).evaluate

      expect(result).to eq(:blocked)
      expect(conversation.reload.label_list).to be_empty
    end

    it 'applies the activation label and allows processing when a keyword matches' do
      result = described_class.new(
        conversation: conversation,
        assistant: assistant,
        message_content: 'Je veux commander'
      ).evaluate

      expect(result).to eq(:allowed)
      expect(conversation.reload.label_list).to include('keyword_match')
      expect(account.labels.find_by(title: 'keyword_match')).to be_present
    end

    it 'allows processing when the activation label is already present' do
      conversation.add_labels('keyword_match')

      result = described_class.new(
        conversation: conversation,
        assistant: assistant,
        message_content: 'bonjour'
      ).evaluate

      expect(result).to eq(:allowed)
    end

    it 'matches substrings when configured' do
      assistant.update!(config: assistant.config.merge('activation_match_mode' => 'substring'))

      result = described_class.new(
        conversation: conversation,
        assistant: assistant,
        message_content: 'je veux un catalogue complet'
      ).evaluate

      expect(result).to eq(:allowed)
    end
  end

  describe '.clear_activation_label!' do
    it 'removes the activation label from the conversation' do
      conversation.add_labels('keyword_match')

      described_class.clear_activation_label!(conversation: conversation, assistant: assistant)

      expect(conversation.reload.label_list).not_to include('keyword_match')
    end

    it 'does nothing when the activation label is not present' do
      conversation.add_labels('commande')

      described_class.clear_activation_label!(conversation: conversation, assistant: assistant)

      expect(conversation.reload.label_list).to eq(['commande'])
    end
  end
end
