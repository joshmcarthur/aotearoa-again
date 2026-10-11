module Colourisers
  module Prompt
    TEXT = <<~PROMPT.squish.freeze
      Colourise the photographic image with historically plausible colours.
      Preserve the exact composition, geometry, faces, clothing details, and scene
      content. If the scan includes a plate holder, mount, film rebate, scanner
      edge, or other equipment or frame, keep it exactly as in the scan: do not
      crop it out, extend the photograph beyond it, colourise it, add text or
      markings to it, or invent content that it is covering. Do not invent detail
      on framing or equipment for the sake of colour. Do not invent major objects,
      people, text, or modern elements. Keep lighting natural to the era. Do not add
      watermarks, logos, decorative borders, or overlaid captions.
    PROMPT
  end
end
