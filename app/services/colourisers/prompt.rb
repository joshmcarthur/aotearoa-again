module Colourisers
  module Prompt
    TEXT = <<~PROMPT.squish.freeze
      The input is a scan that may include a photograph plus existing film edges, mounts,
      captions, labels, or margins. Apply historically plausible colour only to the
      photographed scene—the people, places, and objects the camera captured. Do not add
      grey mattes, borders, halos, or fringes around the scene; do not widen neutral
      margins at the photograph edge. Where the scan already shows non-scene material,
      match the input exactly—do not colourise it or add new detail. Keep the full
      input dimensions and crop: do not remove scan edges, reframe, or extend the scene
      beyond what is visible in the input. Preserve exact composition, geometry, faces,
      clothing, and scene content. Do not invent objects, people, text, or modern
      elements. Keep lighting natural to the era. Do not add watermarks, logos, or
      overlays.
    PROMPT
  end
end
