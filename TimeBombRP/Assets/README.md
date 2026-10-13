# Original TimeBombRP assets

The twelve `.tga` files in this directory are the ready-to-use runtime textures.
They require no image converter, network access, external font, or build step in
World of Warcraft. Paths and hashes are listed in `manifest.json`.

| Texture | Dimensions | Purpose |
| --- | --- | --- |
| `card_back.tga` | 128 × 256 | Identical public back for every unrevealed slot |
| `card_safe.tga` | 128 × 256 | Parted neutral cable, after public revelation |
| `card_defuse.tga` | 128 × 256 | Green mechanical seal and check, after revelation |
| `card_bomb.tga` | 128 × 256 | Red clockwork trigger and flaring fuse, after revelation |
| `emblem_defuser.tga` | 128 × 128 | Private defuser shield |
| `emblem_saboteur.tga` | 128 × 128 | Private theatrical saboteur mask |
| `pliers.tga` | 256 × 256 | Public holder token |
| `chest.tga` | 256 × 256 | Decorative miniature game chest |
| `table.tga` | 1024 × 512 | Burgundy velvet, walnut, and brass table background |
| `ornament.tga` | 128 × 128 | Transparent engraved flourish |
| `progress_on.tga` | 128 × 128 | Completed collective progress seal |
| `progress_off.tga` | 128 × 128 | Unfilled collective progress socket |

All textures are uncompressed TGA type 2, 32-bit BGRA, straight alpha, with
top-left image origin and eight alpha bits. Dimensions are powers of two.
The surface texture is opaque. Every other texture has a transparent border.
The four card alpha channels are **byte-for-byte identical**, including their
anti-aliased silhouette. Types never determine an unrevealed slot's texture.

## Provenance

This set was created specifically for this project. No Time Bomb commercial
illustrations, publisher logo, packaging, characters, or other game textures
were copied. There is no baked text in any runtime texture.

- `Sources/chest_painted.png`, `Sources/table_painted.png`, and
  `Sources/pliers_painted.png` are original images generated with the built-in
  OpenAI imagegen tool on 2026-10-13. Full prompts are preserved in
  `Sources/prompts.json` and `Sources/pliers_prompt.json`. The source files keep
  their original generated alpha. Their runtime derivatives are resized and,
  for transparent props, cropped to their alpha bounds and centered with padding.
- Cards, role emblems, progress seals, and the ornament are original procedural
  illustrations authored in `tools/assets_build.py`. Their shared geometry,
  cable paths, metalwork, mechanical symbols, palette, and seeded parchment
  texture are constructed by the script. They were not image-generated.
- `docs/assets-preview.png` is an asset contact sheet rendered outside WoW.
  Its labels use a local system font solely for documentation. It is not a
  screenshot, mock client, or evidence of native rendering.

These project assets are distributed under the repository's license. Generated
artwork is supplied as project material; this notice makes no representation
that a publisher or Blizzard created or endorsed it.

## Rebuild and verify

Python 3 and Pillow are the only build dependencies. From the repository root:

```sh
python3 tools/assets_build.py
python3 tools/assets_build.py --verify
```

Building is deterministic from the versioned PNG sources and procedural code;
it does not call an image-generation service. Regenerating art from prompts is
not claimed to reproduce the original pixels.

Verification checks TGA header fields, raw byte count, exact dimensions,
power-of-two sizing, image orientation, transparent corner pixels, full alpha
range, identical card silhouettes, and SHA-256 hashes. It also decodes every
file through Pillow and checks that its BGRA pixels match the stored top-down
pixel stream.

The contact sheet was visually inspected outside the game. Native WoW texture
loading still requires the repository's in-game checklist; a Python image
decoder cannot establish that this occurred.
