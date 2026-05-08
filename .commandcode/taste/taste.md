# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# UI/UX
- Do not display raw URLs or implementation details in user-facing dialogs; show only user-friendly labels. Confidence: 0.75
- Use radius tokens (8/10/12) for all rectangular UI corners; preserve 999 for pills/chips, 70 for circular elements, and 2 for tiny accents. Confidence: 0.85
- For episode cards: left-align image without padding, show title once with duration, reduce inter-card spacing, and remove redundant text labels when icons convey the same info. Confidence: 0.70
- For movie views: omit episode-start UI entirely; show a download button below the play button, styled differently from the episode-context download button. Confidence: 0.65

