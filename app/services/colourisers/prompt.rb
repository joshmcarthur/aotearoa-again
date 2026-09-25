module Colourisers
  module Prompt
    TEXT = <<~PROMPT.squish.freeze
      Colourise this historical black-and-white photograph with historically
      plausible colours. Preserve the exact composition, geometry, faces, clothing
      details, and scene content. Do not invent major objects, people, text, or
      modern elements. Keep lighting natural to the era. Do not add text overlay,
      watermarks, logos, borders, modern clothing, anachronisms, or invented objects.
    PROMPT
  end
end
