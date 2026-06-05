class Captain::Conversation::KeywordActivationGate
  DEFAULT_ACTIVATION_LABEL = 'keyword_match'.freeze

  def initialize(conversation:, assistant:, message_content:)
    @conversation = conversation
    @assistant = assistant
    @message_content = message_content.to_s
  end

  def evaluate
    return :allowed unless keyword_activation_enabled?
    return :allowed if activation_label_present?
    return :blocked unless keyword_match?

    apply_activation_label!
    :allowed
  end

  def self.clear_activation_label!(conversation:, assistant:)
    return if assistant.blank?

    label = normalized_label(assistant.activation_label)
    labels = Array(conversation.label_list).map { |item| item.to_s.downcase }
    return unless labels.include?(label)

    remaining_labels = Array(conversation.label_list).reject { |item| item.to_s.downcase == label }
    conversation.update!(label_list: remaining_labels)
  end

  def self.normalized_label(label)
    label.to_s.downcase.strip
  end

  private

  def keyword_activation_enabled?
    @assistant.keyword_activation_enabled?
  end

  def activation_label_present?
    self.class.normalized_label(@assistant.activation_label).in?(
      Array(@conversation.label_list).map { |label| label.to_s.downcase }
    )
  end

  def keyword_match?
    keywords = @assistant.activation_keywords
    return false if keywords.blank?

    if @assistant.activation_word_match_mode?
      word_match?(keywords)
    else
      substring_match?(keywords)
    end
  end

  def word_match?(keywords)
    normalized_words = @message_content.downcase.scan(/\p{L}[\p{L}\p{N}_]*/u)
    keyword_set = keywords.map { |keyword| keyword.to_s.downcase.strip }.compact_blank

    keyword_set.any? { |keyword| normalized_words.include?(keyword) }
  end

  def substring_match?(keywords)
    normalized_content = @message_content.downcase
    keywords.any? do |keyword|
      normalized_keyword = keyword.to_s.downcase.strip
      normalized_keyword.present? && normalized_content.include?(normalized_keyword)
    end
  end

  def apply_activation_label!
    label_title = self.class.normalized_label(@assistant.activation_label)
    ensure_activation_label_exists!(label_title)
    @conversation.add_labels(label_title)
  end

  def ensure_activation_label_exists!(label_title)
    @assistant.account.labels.find_or_create_by!(title: label_title)
  end
end
