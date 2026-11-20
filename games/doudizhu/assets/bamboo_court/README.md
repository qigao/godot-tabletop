# Bamboo Court

The DouDiZhu layout uses these assets through its media and theme resources.
The illustrations are original generated artwork. The reference project informed the placement of seats, public cards, actions and results.

| File | Use |
| --- | --- |
| `felt.webp` | Jade tabletop with bamboo shadows. The renderer crops to fill without stretching the image. |
| `portraits.webp` | Three seat portraits from a 2 × 2 source atlas. The first three 192 × 192 tiles are configured in `media.tres`. |
| `card-back.webp` | Brass bamboo seal for hidden hands, bottom cards and dealing. |
| `table_theme.tres` | Seat plates, action buttons, focus rings and settlement frame. |
| `table-music.wav`, `tension-music.wav` | Original eight-second plucked loops. Bomb and rocket events select the second loop. |
| `paper.wav`, `deal.wav`, `settlement.wav` | Original card, dealing and result sounds. |

The corner and center suit marks use code-drawn pips. The voice cues continue to reference the Mandarin sample recordings under `../voice/`.
Regenerate the WAV files with `python scripts/synthesize_bamboo_audio.py` from the project root.

## Artwork prompts

The generated PNGs were encoded as WebP at the game asset dimensions.

### Felt

Use case: stylized-concept. Create an original wide landscape texture for the playing field of a polished Chinese local card-table game named Bamboo Court. Overhead flat painted game surface, no perspective, rich dark pine jade woven felt, softly lit center with delicate grain, broad continuous dark jade negative space across the middle band and from 18% to 82% width. Place softly painted bamboo leaf shadows and very restrained aged brass edge ornament in the outer left and right sides, visible even when only the middle 50% of image height is displayed. A hint of smoked wood at the far outer edges. The feel is a warm private game room, composed and grounded, not casino-like. Full bleed clean edges. No players, cards, dice, icons, lettering, buttons, watermarks, logos, furniture or hard rectangular insets. This is a production background texture; readable UI is drawn separately. Landscape aspect near 3:2 or wider.

### Portraits

Use case: illustration-story. A single square texture atlas of four original bust portraits for a Chinese casual tabletop card game called Bamboo Court, evenly divided into a precise 2-by-2 grid with identical square tile sizes, no margins, no grid lines and no text. Top left: self-assured young adult woman with a short black bob and a pale gold and dark pine jacket on muted jade. Top right: thoughtful middle-aged man with round glasses and a slate sweater on muted rust. Bottom left: cheerful adult woman with a blue scarf and swept-up dark hair on muted indigo. Bottom right: easygoing older man with white hair and brick-coral cardigan on deep muted green. Each is an independent cropped head-and-shoulders illustration, facing slightly toward the viewer, face centered in its own tile and legible at 48 pixels. Natural expressive faces, printed gouache illustration with restrained highlights and graphic shapes, consistent original proportions. Entire tile has opaque dark color, silhouettes kept comfortably inside the center, no border frames, no ornaments or elements crossing tile edges, no text, marks, logo or existing characters. One 1:1 image.

### Back

Use case: stylized-concept. An original portrait-format playing card reverse for a card game theme called Bamboo Court. A precise straight-on full-bleed flat card design, aspect ratio about 2:3, no perspective or presentation mockup. Very dark pine jade cloth with a small brass bamboo-stem seal in the center, a clean double brass inset linear border about 6% from all edges, beautifully restrained diagonal leaf patterns inside the frame, mirrored understated corners. Clean readability as a small 20 pixel wide card-back in a row, strong silhouette, visually distinct from commercially branded game card backs. Warm gold and green only. Straight uniform outside edges with no extra background outside the card, no text, letters, numerals, rank, suit, logo or watermark.
