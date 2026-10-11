module Colourisers
  module Prompt
    TEXT = <<~PROMPT.squish.freeze
      The input is a scan that may include a photograph plus surrounds such as a
      frame, mount, caption, label, margin, or equipment. Apply historically
      plausible colour only to the photograph—the people, places, and objects the
      camera captured. Keep every surround exactly as in the input image: same
      greyscale, same text, same marks; do not colourise surrounds or add new
      detail to them. Keep the full scan crop: do not remove surrounds, reframe,
      or extend the photograph beyond the edges visible in the input. Preserve exact
      composition, geometry, faces, clothing, and scene content inside the
      photograph. Do not invent objects, people, text, or modern elements. Keep
      lighting natural to the era. Do not add watermarks, logos, or overlays.
    PROMPT
  end
end
