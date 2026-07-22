# RubyLLM 1.16's OpenRouter paint path ignores `with:` and `params:`, and omits
# max_tokens. OpenRouter then reserves the model's full output window (~29k for
# Gemini image models), which 402s against per-key credit limits even when the
# real generation would cost pennies.
module RubyLlmOpenrouterImagesPatch
  DEFAULT_MAX_TOKENS = 4096

  def render_image_payload(prompt, model:, size:, with: nil, mask: nil, params: {}) # rubocop:disable Lint/UnusedMethodArgument,Metrics/ParameterLists
    if size
      RubyLLM.logger.debug { "Ignoring size #{size}. OpenRouter image generation does not support size parameter." }
    end

    extras = params.to_h.stringify_keys.except("negative_prompt").transform_keys(&:to_sym)

    {
      model: model,
      messages: [
        {
          role: "user",
          content: openrouter_image_content(prompt, with)
        }
      ],
      modalities: %w[image text],
      max_tokens: DEFAULT_MAX_TOKENS
    }.merge(extras)
  end

  private

  def openrouter_image_content(prompt, with)
    sources = Array(with).compact.reject { |source| blank_openrouter_attachment?(source) }
    return prompt if sources.empty?

    parts = [ { type: "text", text: prompt } ]
    sources.each do |source|
      attachment = RubyLLM::Attachment.new(source)
      parts << {
        type: "image_url",
        image_url: {
          url: attachment.url? ? attachment.source.to_s : attachment.for_llm
        }
      }
    end
    parts
  end

  def blank_openrouter_attachment?(source)
    return true if source.nil?
    return source.strip.empty? if source.is_a?(String)
    return !source.attached? if source.respond_to?(:attached?)

    false
  end
end
