require "stringio"

module Colourisers
  class RubyLlmColouriser
    class Error < StandardError; end

    def call(attachment:, model:, prompt: Prompt::TEXT)
      raise Error, "Original image missing" unless attachment&.attached?
      raise Error, "Model required" unless model

      painted = RubyLLM.paint(
        prompt,
        model: model.model_id,
        provider: model.provider.to_sym,
        with: attachment,
        provider_options: { output_format: "png" }
      )
      image = painted.is_a?(Array) ? painted.first : painted
      raise Error, "Empty colourised image" if image.blank?

      blob = image.to_blob
      raise Error, "Empty colourised image" if blob.blank?

      {
        io: StringIO.new(blob),
        filename: "colourised-#{model.model_id.parameterize}.png",
        content_type: image.mime_type.presence || "image/png",
        model: model,
        prompt: prompt,
        usage: usage_from(image)
      }
    rescue RubyLLM::Error => e
      raise Error, e.message
    end

    private

    def usage_from(image)
      {
        "input_tokens" => image.tokens.input,
        "output_tokens" => image.tokens.output,
        "cost" => image.cost.total
      }
    end
  end
end
