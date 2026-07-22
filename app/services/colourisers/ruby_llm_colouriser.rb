require "stringio"

module Colourisers
  class RubyLlmColouriser
    class Error < StandardError; end

    def call(attachment:, model:, prompt: Prompt::TEXT)
      raise Error, "Original image missing" unless attachment&.attached?
      raise Error, "Model required" unless model

      # Cap max_tokens so OpenRouter does not reserve the model's full ~29k
      # output window against the API key's daily/weekly credit limit.
      image = RubyLLM.paint(
        prompt,
        model: model.model_id,
        provider: model.provider.to_sym,
        with: attachment,
        params: {
          max_tokens: RubyLlmOpenrouterImagesPatch::DEFAULT_MAX_TOKENS,
          negative_prompt: Prompt::NEGATIVE
        }
      )

      blob = image.to_blob
      raise Error, "Empty colourised image" if blob.blank?

      {
        io: StringIO.new(blob),
        filename: "colourised-#{model.model_id.parameterize}.png",
        content_type: image.mime_type.presence || "image/png",
        model: model,
        prompt: prompt
      }
    rescue RubyLLM::Error => e
      raise Error, e.message
    end
  end
end
