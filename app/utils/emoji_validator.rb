class EmojiValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?
    return if valid_emoji?(value)

    record.errors.add(attribute, options[:message] || I18n.t('activerecord.errors.messages.invalid_emoji'))
  end

  private

  def valid_emoji?(value)
    emoji_regex = /\A[\p{Emoji}\u{1F3FB}-\u{1F3FF}\u{200D}\u{FE0F}]+\z/
    value.present? && value.match?(emoji_regex)
  end
end
