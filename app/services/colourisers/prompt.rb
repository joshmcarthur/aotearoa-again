module Colourisers
  module Prompt
    TEXT = <<~PROMPT.squish.freeze
      Colourise this historical black-and-white photograph with historically
      plausible colours. Preserve the exact composition, geometry, faces, clothing
      details, and scene content. If the scan includes a plate holder, mount, film
      rebate, scanner edge, or other equipment or frame, keep it in the image and
      colourise it as a physical object. Do not crop it out, extend the photograph
      beyond it, or invent content that the frame or equipment is covering. Do not
      invent major objects, people, text, or modern elements. Keep lighting natural
      to the era. Do not add watermarks, logos, decorative borders, or overlaid
      captions.
    PROMPT
  end
end
